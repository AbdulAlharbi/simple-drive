Rails.application.routes.draw do
  namespace :v1 do
    post "blobs", to: "blobs#create"
    # Wildcard so ids containing "/" or "." work as documented
    # (ids are opaque strings and may look like paths).
    get "blobs/*id", to: "blobs#show", format: false
  end
end
