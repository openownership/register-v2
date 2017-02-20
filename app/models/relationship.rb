class Relationship
  include Mongoid::Document

  field :interests, type: Array, default: []

  belongs_to :source, class_name: 'Entity'
  belongs_to :target, class_name: 'Entity'

  embeds_many :intermediate_entities, class_name: 'Entity'
  embeds_many :intermediate_relationships, class_name: 'Relationship'

  index source_id: 1
  index target_id: 1
end
