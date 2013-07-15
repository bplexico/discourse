class CategoryList
  include ActiveModel::Serialization

  attr_accessor :categories,
                :topic_users,
                :uncategorized,
                :draft,
                :draft_key,
                :draft_sequence

  def initialize(guardian=nil)
    @guardian = guardian || Guardian.new

    find_relevant_topics
    find_categories

    prune_empty
    add_uncategorized
    find_user_data
  end

  private

    # Retrieve a list of all the topics we'll need
    def find_relevant_topics
      @topics_by_category_id = {}
      category_featured_topics = CategoryFeaturedTopic.select([:category_id, :topic_id]).order(:rank)
      @topics_by_id = {}

      @all_topics = Topic.where(id: category_featured_topics.map(&:topic_id))
      @all_topics.each do |t|
        @topics_by_id[t.id] = t
      end

      category_featured_topics.each do |cft|
        @topics_by_category_id[cft.category_id] ||= []
        @topics_by_category_id[cft.category_id] << cft.topic_id
      end
    end

    # Find a list of all categories to associate the topics with
    def find_categories
      @categories = Category
                      .includes(:featured_users)
                      .secured(@guardian)
                      .order('COALESCE(categories.topics_week, 0) DESC')
                      .order('COALESCE(categories.topics_month, 0) DESC')
                      .order('COALESCE(categories.topics_year, 0) DESC')

      @categories = @categories.to_a
      @categories.each do |c|
        topics_in_cat = @topics_by_category_id[c.id]
        if topics_in_cat.present?
          c.displayable_topics = []
          topics_in_cat.each do |topic_id|
            topic = @topics_by_id[topic_id]
            if topic.present?
              topic.category = c
              c.displayable_topics << topic
            end
          end
        end
      end
    end

    # Add the uncategorized "magic" category
    def add_uncategorized
      # Support for uncategorized topics
      uncategorized_topics = Topic.uncategorized_topics

      if uncategorized_topics.present?
        uncategorized = UncategorizedCategory.new(uncategorized_topics)

        # Find the appropriate place to insert it:
        insert_uncategorized_category(uncategorized)

        add_uncategorized_topics(uncategorized_topics) if uncategorized.present?
      end
    end

    def add_uncategorized_topics(uncategorized_topics)
      if @all_topics.present?
        @all_topics << uncategorized_topics
        @all_topics.flatten!
      end
    end

    def insert_uncategorized_category(uncategorized)
      insert_at = catch(:idx){
        @categories.each_with_index do |c, idx|
            throw(:idx, idx) if (uncategorized.topics_week || 0) > (c.topics_week || 0)
        end
        nil
      }

      @categories.insert(insert_at || @categories.size, uncategorized)
    end

  # Remove any empty topics unless we can create them (so we can see the controls)
    def prune_empty
      unless @guardian.can_create?(Category)
        # Remove categories with no featured topics unless we have the ability to edit one
        @categories.delete_if { |c| c.displayable_topics.blank? }
      end
    end

    # Get forum topic user records if appropriate
    def find_user_data
      if @guardian.current_user && @all_topics.present?
        topic_lookup = TopicUser.lookup_for(@guardian.current_user, @all_topics)

        # Attach some data for serialization to each topic
        @all_topics.each { |ft| ft.user_data = topic_lookup[ft.id] }
      end
    end
end