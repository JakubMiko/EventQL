# frozen_string_literal: true

require "rails_helper"

RSpec.describe ImageAttachmentService, type: :service do
  # A tiny 1x1 pixel red PNG image in base64
  let(:valid_base64_image) do
    "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="
  end

  # A tiny 1x1 pixel WebP image in base64
  let(:valid_webp_image) do
    "data:image/webp;base64,UklGRiQAAABXRUJQVlA4IBgAAAAwAQCdASoBAAEAAwA0JaQAA3AA/vuUAAA="
  end

  let(:event) { create(:event) }

  describe ".call" do
    context "with valid base64 PNG image" do
      it "attaches the image successfully" do
        result = described_class.call(
          record: event,
          attachment_name: :image,
          image_data: valid_base64_image,
          filename: "test.png"
        )

        expect(result).to be_success
        expect(event.image).to be_attached
        expect(event.image.filename.to_s).to eq("test.png")
        expect(event.image.content_type).to eq("image/png")
      end
    end

    context "with valid base64 WebP image" do
      it "attaches the image successfully" do
        result = described_class.call(
          record: event,
          attachment_name: :image,
          image_data: valid_webp_image,
          filename: "photo.webp"
        )

        expect(result).to be_success
        expect(event.image).to be_attached
        expect(event.image.filename.to_s).to eq("photo.webp")
        expect(event.image.content_type).to eq("image/webp")
      end
    end

    context "without filename" do
      it "generates filename from content type" do
        result = described_class.call(
          record: event,
          attachment_name: :image,
          image_data: valid_base64_image
        )

        expect(result).to be_success
        expect(event.image).to be_attached
        expect(event.image.filename.to_s).to eq("upload.png")
      end
    end

    context "with whitespace in base64 data" do
      it "strips whitespace and attaches successfully" do
        image_with_whitespace = valid_base64_image.sub(";base64,", ";base64,\n  ")

        result = described_class.call(
          record: event,
          attachment_name: :image,
          image_data: image_with_whitespace,
          filename: "test.png"
        )

        expect(result).to be_success
        expect(event.image).to be_attached
      end
    end

    context "with nil image_data" do
      it "returns success without attaching" do
        result = described_class.call(
          record: event,
          attachment_name: :image,
          image_data: nil
        )

        expect(result).to be_success
        expect(event.image).not_to be_attached
      end
    end

    context "with empty string image_data" do
      it "returns success without attaching" do
        result = described_class.call(
          record: event,
          attachment_name: :image,
          image_data: ""
        )

        expect(result).to be_success
        expect(event.image).not_to be_attached
      end
    end

    context "with invalid data URI format" do
      it "returns failure with descriptive error" do
        result = described_class.call(
          record: event,
          attachment_name: :image,
          image_data: "not-a-data-uri",
          filename: "test.png"
        )

        expect(result).to be_failure
        expect(result.failure).to include("Invalid image format")
      end
    end

    context "with missing base64 prefix" do
      it "returns failure" do
        result = described_class.call(
          record: event,
          attachment_name: :image,
          image_data: "data:image/png,plain-text-not-base64",
          filename: "test.png"
        )

        expect(result).to be_failure
        expect(result.failure).to include("Invalid image format")
      end
    end

    context "with empty base64 data" do
      it "returns failure" do
        result = described_class.call(
          record: event,
          attachment_name: :image,
          image_data: "data:image/png;base64,",
          filename: "test.png"
        )

        expect(result).to be_failure
        expect(result.failure).to include("Base64 data is empty")
      end
    end

    context "with invalid base64 encoding" do
      it "returns failure" do
        result = described_class.call(
          record: event,
          attachment_name: :image,
          image_data: "data:image/png;base64,not-valid-base64!!!",
          filename: "test.png"
        )

        expect(result).to be_failure
        expect(result.failure).to include("Invalid base64 encoding")
      end
    end

    context "when replacing an existing image" do
      before do
        # Attach initial image
        described_class.call(
          record: event,
          attachment_name: :image,
          image_data: valid_base64_image,
          filename: "old.png"
        )
      end

      it "replaces the old image with new one" do
        result = described_class.call(
          record: event,
          attachment_name: :image,
          image_data: valid_webp_image,
          filename: "new.webp"
        )

        expect(result).to be_success
        expect(event.image).to be_attached
        expect(event.image.filename.to_s).to eq("new.webp")
        expect(event.image.content_type).to eq("image/webp")
      end
    end
  end
end
