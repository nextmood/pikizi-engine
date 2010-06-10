xml.instruct!

xml.reviews do
  @reviews.each do |review|
    xml.review("id" => review.id.to_s, "by" => review.author, "written_at" => review.written_at.to_s) do
      xml.body review.content
    end
  end
end