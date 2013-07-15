class UncategorizedCategory < Category
  def initialize(uncategorized_topics)
    super({name:            SiteSetting.uncategorized_name,
           slug:            Slug.for(SiteSetting.uncategorized_name),
           color:           SiteSetting.uncategorized_color,
           text_color:      SiteSetting.uncategorized_text_color,
           featured_topics: uncategorized_topics}.merge(Topic.totals))
  end
end