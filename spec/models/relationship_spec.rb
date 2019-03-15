require 'rails_helper'

RSpec.describe Relationship do
  subject do
    described_class.new(
      source_id: 1,
      target_id: 2,
      interests: [3, 4],
      sample_date: sample_date,
      provenance: provenance,
    )
  end

  let(:sample_date) { "2016-03-17" }
  let(:provenance) { Provenance.new }

  describe '#sample_date' do
    it "returns an iso8601 date" do
      expect(subject.sample_date).to eq(ISO8601::Date.new(sample_date))
    end

    context "when sample_date is nil" do
      let(:sample_date) { nil }

      it "returns nil" do
        expect(subject.sample_date).to be_nil
      end
    end
  end

  describe '#to_builder' do
    it 'returns a JSON representation' do
      expect(JSON.parse(subject.to_builder.target!)).to eq(
        'source_id' => '1',
        'target_id' => '2',
        'interests' => [3, 4],
        'sample_date' => [2016, 3, 17],
        'provenance' => {
          'source_url' => nil,
          'source_name' => nil,
          'retrieved_at' => nil,
          'imported_at' => nil,
        },
      )
    end
  end

  describe '#source' do
    context 'when the source entity has a master_entity' do
      let(:master_person) { create(:natural_person) }
      let(:person) { create(:natural_person, master_entity: master_person) }
      let(:company) { create(:legal_entity) }

      subject do
        create(:relationship, source: person, target: company)
      end

      it 'returns the master_entity' do
        expect(subject.source).to eq master_person
      end
    end

    context 'when the source entity has no master_entity' do
      let(:person) { create(:natural_person) }
      let(:company) { create(:legal_entity) }

      subject do
        create(:relationship, source: person, target: company)
      end

      it 'returns the source' do
        expect(subject.source).to eq person
      end
    end
  end

  describe '#keys_for_uniq_grouping' do
    let(:relationship) do
      create(
        :relationship,
        interests: [
          'right-to-appoint-and-remove-directors',
          'ownership-of-shares-25-to-50-percent',
        ],
      )
    end

    let(:source_id) { relationship.source.id.to_s }
    let(:target_id) { relationship.target.id.to_s }

    it 'returns an array of source_id, target_id and alphabetically sorted interests' do
      expected = [
        source_id,
        target_id,
        'ownership-of-shares-25-to-50-percent',
        'right-to-appoint-and-remove-directors',
      ]
      expect(relationship.keys_for_uniq_grouping).to eq(expected)
    end

    context 'when there are interest objects' do
      before do
        relationship.interests << { type: 'voting-rights-range', share_min: 10, share_max: 20 }
        relationship.save!
        # Mongo will convert keys in hashes, but rather than guessing what it
        # will do when we put data in, just round-trip it through the db
        relationship.reload
      end

      it 'extracts the types from the interests' do
        expected = [
          source_id,
          target_id,
          'ownership-of-shares-25-to-50-percent',
          'right-to-appoint-and-remove-directors',
          'voting-rights-range',
        ]
        expect(relationship.keys_for_uniq_grouping).to eq(expected)
      end

      it 'deals with interests with missing types' do
        relationship.interests << { share_min: 10, share_max: 20 }
        relationship.save!
        relationship.reload
        expected = [
          source_id,
          target_id,
          '',
          'ownership-of-shares-25-to-50-percent',
          'right-to-appoint-and-remove-directors',
          'voting-rights-range',
        ]
        expect(relationship.keys_for_uniq_grouping).to eq(expected)
      end
    end
  end
end
