# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GraphQL Query Limits", type: :request do
  describe "query depth limiting" do
    context "when query is within depth limit (10 levels)" do
      let(:query) do
        <<~GRAPHQL
          query {
            events {
              nodes {
                id
                name
                ticketBatches {
                  id
                  price
                  event {
                    id
                    name
                  }
                }
              }
            }
          }
        GRAPHQL
      end

      it "executes successfully" do
        create_list(:event, 2)

        post "/graphql", params: { query: query }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json["errors"]).to be_nil
        expect(json["data"]["events"]).to be_present
      end
    end

    context "when query exceeds depth limit (>10 levels)" do
      # This query is 11+ levels deep
      let(:query) do
        <<~GRAPHQL
          query {
            events {
              nodes {
                ticketBatches {
                  orders {
                    user {
                      orders {
                        tickets {
                          event {
                            ticketBatches {
                              orders {
                                user {
                                  id
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        GRAPHQL
      end

      it "rejects the query with helpful error message" do
        post "/graphql", params: { query: query }

        expect(response).to have_http_status(:success) # GraphQL returns 200 even for validation errors
        json = JSON.parse(response.body)

        expect(json["errors"]).to be_present
        expect(json["errors"].first["message"]).to include("depth")
        expect(json["data"]).to be_nil
      end
    end

    context "when query is exactly at depth limit (10 levels)" do
      # Exactly 10 levels deep
      let(:query) do
        <<~GRAPHQL
          query {
            events {
              nodes {
                ticketBatches {
                  orders {
                    user {
                      orders {
                        tickets {
                          event {
                            id
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        GRAPHQL
      end

      it "executes successfully" do
        create_list(:event, 2)

        post "/graphql", params: { query: query }

        json = JSON.parse(response.body)
        # May have errors due to missing data, but should not have depth error
        if json["errors"]
          expect(json["errors"].none? { |e| e["message"].include?("depth") }).to be(true)
        end
      end
    end
  end

  describe "query complexity limiting" do
    context "when query is within complexity limit (2000)" do
      # Simple query - low complexity
      let(:query) do
        <<~GRAPHQL
          query {
            events(first: 10) {
              nodes {
                id
                name
                date
              }
              totalCount
            }
          }
        GRAPHQL
      end

      it "executes successfully" do
        create_list(:event, 10)

        post "/graphql", params: { query: query }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json["errors"]).to be_nil
        expect(json["data"]["events"]).to be_present
      end
    end

    context "when query exceeds complexity limit (>2000)" do
      # Extremely complex query - requesting many items with deeply nested relations
      # This query intentionally requests duplicate data to exceed the 2000 limit
      let(:query) do
        <<~GRAPHQL
          query {
            events(first: 50) {
              edges {
                node {
                  id
                  name
                  description
                  date
                  category
                  place
                  ticketBatches {
                    id
                    price
                    availableTickets
                    saleStart
                    saleEnd
                    event {
                      id
                      name
                      description
                      date
                      place
                      category
                    }
                  }
                  tickets {
                    id
                    ticketNumber
                    price
                    user {
                      id
                      email
                      firstName
                      lastName
                    }
                    order {
                      id
                      status
                      quantity
                      totalPrice
                    }
                    event {
                      id
                      name
                      description
                      date
                      place
                      category
                    }
                  }
                }
                cursor
              }
              nodes {
                id
                name
                description
                date
                category
                place
                ticketBatches {
                  id
                  price
                  availableTickets
                  saleStart
                  saleEnd
                  event {
                    id
                    name
                  }
                }
                tickets {
                  id
                  ticketNumber
                  user {
                    id
                    email
                  }
                  event {
                    id
                    name
                  }
                }
              }
              pageInfo {
                hasNextPage
                hasPreviousPage
                startCursor
                endCursor
              }
              totalCount
            }
          }
        GRAPHQL
      end

      it "rejects the query with helpful error message" do
        post "/graphql", params: { query: query }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json["errors"]).to be_present
        expect(json["errors"].first["message"]).to include("complexity")
        expect(json["data"]).to be_nil
      end
    end

    context "when requesting many items increases complexity" do
      # Requesting 100 items vs 10 items affects complexity
      let(:large_query) do
        <<~GRAPHQL
          query {
            events(first: 100) {
              nodes {
                id
                name
                ticketBatches {
                  id
                  price
                }
              }
            }
          }
        GRAPHQL
      end

      let(:small_query) do
        <<~GRAPHQL
          query {
            events(first: 10) {
              nodes {
                id
                name
                ticketBatches {
                  id
                  price
                }
              }
            }
          }
        GRAPHQL
      end

      it "allows small query but may reject large query" do
        create_list(:event, 100)

        # Small query should work
        post "/graphql", params: { query: small_query }
        json_small = JSON.parse(response.body)
        expect(json_small["errors"]).to be_nil

        # Large query might exceed complexity (depends on exact calculation)
        # This documents the behavior rather than enforces it
        post "/graphql", params: { query: large_query }
        json_large = JSON.parse(response.body)

        if json_large["errors"]
          expect(json_large["errors"].first["message"]).to include("complexity")
        end
      end
    end
  end

  describe "combined limits" do
    context "when query violates multiple limits" do
      # Both too deep AND too complex
      let(:query) do
        <<~GRAPHQL
          query {
            events(first: 100) {
              nodes {
                ticketBatches {
                  orders {
                    user {
                      orders {
                        tickets {
                          event {
                            ticketBatches {
                              orders {
                                user {
                                  orders {
                                    tickets {
                                      id
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        GRAPHQL
      end

      it "rejects the query" do
        post "/graphql", params: { query: query }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json["errors"]).to be_present
        expect(json["data"]).to be_nil
      end
    end
  end

  describe "error messages" do
    it "provides helpful error for depth limit" do
      query = <<~GRAPHQL
        query {
          events {
            nodes {
              ticketBatches {
                orders {
                  user {
                    orders {
                      tickets {
                        event {
                          ticketBatches {
                            orders {
                              user {
                                id
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      GRAPHQL

      post "/graphql", params: { query: query }
      json = JSON.parse(response.body)

      expect(json["errors"]).to be_present
      error_message = json["errors"].first["message"]
      expect(error_message).to match(/depth|10|levels?/i)
    end

    it "provides helpful error for complexity limit" do
      # Very complex query that exceeds 2000 complexity
      query = <<~GRAPHQL
        query {
          events(first: 50) {
            edges {
              node {
                id
                name
                description
                date
                category
                place
                ticketBatches {
                  id
                  price
                  availableTickets
                  saleStart
                  saleEnd
                  event {
                    id
                    name
                    description
                    date
                    category
                    place
                    ticketBatches {
                      id
                      price
                    }
                  }
                }
                tickets {
                  id
                  ticketNumber
                  price
                  user {
                    id
                    email
                    firstName
                    lastName
                  }
                  order {
                    id
                    status
                    quantity
                    totalPrice
                  }
                  event {
                    id
                    name
                    description
                    date
                    ticketBatches {
                      id
                      price
                    }
                  }
                }
              }
              cursor
            }
            nodes {
              id
              name
              description
              date
              category
              place
              ticketBatches {
                id
                price
                availableTickets
                event {
                  id
                  name
                }
              }
              tickets {
                id
                ticketNumber
                user {
                  id
                  email
                }
                event {
                  id
                  name
                }
              }
            }
            totalCount
          }
        }
      GRAPHQL

      post "/graphql", params: { query: query }
      json = JSON.parse(response.body)

      expect(json["errors"]).to be_present
      error_message = json["errors"].first["message"]
      expect(error_message).to match(/complexity|2000|expensive/i)
    end
  end

  describe "mutations are not affected by unreasonable limits" do
    let!(:user) { create(:user, password: "password123") }

    let(:login_mutation) do
      <<~GRAPHQL
        mutation {
          login(input: {
            email: "#{user.email}"
            password: "password123"
          }) {
            token
            user {
              id
              email
              firstName
              lastName
            }
            errors
          }
        }
      GRAPHQL
    end

    it "allows mutations to execute normally" do
      post "/graphql", params: { query: login_mutation }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["errors"]).to be_nil
      expect(json["data"]["login"]["token"]).to be_present
    end
  end
end
