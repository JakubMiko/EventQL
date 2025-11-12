# frozen_string_literal: true

# Service for attaching images from base64 data URI to ActiveStorage attachments
#
# Usage:
#   ImageAttachmentService.call(
#     record: event,
#     attachment_name: :image,
#     image_data: "data:image/png;base64,iVBORw0KGgo...",
#     filename: "photo.png"
#   )
#
class ImageAttachmentService < ApplicationService
  attr_reader :record, :attachment_name, :image_data, :filename

  def initialize(record:, attachment_name:, image_data:, filename: nil)
    @record = record
    @attachment_name = attachment_name
    @image_data = image_data
    @filename = filename
  end

  def call
    return Success(nil) if image_data.blank?

    # Parse data URI format: "data:image/png;base64,iVBORw0KGgo..."
    match = image_data.match(/^data:(.*?);base64,(.*)$/m)

    unless match
      return Failure("Invalid image format. Expected data URI like: data:image/png;base64,...")
    end

    content_type = match[1]
    encoded_data = match[2]

    # Remove whitespace/newlines from base64 string
    encoded_data = encoded_data.gsub(/\s+/, "")

    if encoded_data.empty?
      return Failure("Base64 data is empty")
    end

    # Decode base64 to binary
    begin
      decoded_data = Base64.strict_decode64(encoded_data)
    rescue ArgumentError => e
      return Failure("Invalid base64 encoding: #{e.message}")
    end

    # Determine filename
    final_filename = filename || "upload.#{content_type.split('/').last}"

    # Create IO object for ActiveStorage
    io = StringIO.new(decoded_data)
    io.set_encoding(Encoding::BINARY)

    # Attach to the record
    record.public_send(attachment_name).attach(
      io: io,
      filename: final_filename,
      content_type: content_type
    )

    Success(record.public_send(attachment_name))
  rescue StandardError => e
    Failure("Image attachment failed: #{e.message}")
  end
end
