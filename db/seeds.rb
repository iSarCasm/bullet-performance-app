# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)

ActiveRecord::Base.connection.transaction do
  articles = 10_000.times.map do
    { title: "Article #{SecureRandom.hex{8}}", body: "Some body" }
  end

  article_ids = Article.upsert_all(articles, returning: [:id]).map { |x| x["id" ]}
  comments = article_ids.map do |ar_id|
    { body:"Comment #{SecureRandom.hex{8}}", author: "Author #{SecureRandom.hex{8}}" , article_id: ar_id }
  end
  Comment.upsert_all(comments)
end
