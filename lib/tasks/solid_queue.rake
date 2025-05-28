namespace :solid_queue do
  desc "Load SolidQueue schema"
  task load_schema: :environment do
    load Rails.root.join("db/queue_schema.rb")
    puts "SolidQueue schema loaded successfully!"
  end
end
