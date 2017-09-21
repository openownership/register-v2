require 'rails_helper'

RSpec.describe Entity do
  it_behaves_like "acts as entity"

  describe '.find_or_unknown' do
    subject { Entity.find_or_unknown(id) }

    context "when id is id of a normal entity" do
      let(:id) { "1234" }

      it "finds the entity" do
        expect(Entity).to receive(:find).with(id).and_return(:entity)
        expect(subject).to eq(:entity)
      end
    end

    context "when id is id of an unknown persons entity" do
      let(:id) { 'unknown-person-statement' }

      it "returns an unknown persons entity" do
        expect(subject).to be_a(UnknownPersonsEntity)
      end

      it "returns entity with same id" do
        expect(subject.id).to eq(id)
      end
    end
  end

  describe '#relationships_as_target' do
    let(:entity) { Entity.new }
    subject { entity.relationships_as_target }

    context "when entity is a Entity::Types::NATURAL_PERSON" do
      before { entity.type = Entity::Types::NATURAL_PERSON }

      it "returns empty array" do
        expect(subject).to eq([])
      end
    end

    context "when entity is not a Entity::Types::NATURAL_PERSON" do
      before { entity.type = nil }

      context "when entity is target of some persisted relationships" do
        before do
          allow(entity).to receive(:_relationships_as_target).and_return([:relationship])
        end

        it "returns those relationships" do
          expect(subject).to eq([:relationship])
        end
      end

      context "when entity is target of no persisted relationships" do
        before do
          allow(entity).to receive(:_relationships_as_target).and_return([])
        end

        it "returns an array containing a relationship to an unknown persons entity" do
          expect(subject.count).to eq(1)
          expect(subject[0].source).to eq(UnknownPersonsEntity.new(id: "#{entity.id}#{Entity::UNKNOWN_ID_MODIFIER}"))
          expect(subject[0].target).to eq(entity)
        end
      end
    end
  end

  describe '#natural_person?' do
    subject { Entity.new(type: type).natural_person? }

    context "when entity type is Entity::Types::NATURAL_PERSON" do
      let(:type) { Entity::Types::NATURAL_PERSON }

      it "returns true" do
        expect(subject).to be true
      end
    end

    context "when entity type is not Entity::Types::NATURAL_PERSON" do
      let(:type) { Entity::Types::LEGAL_ENTITY }

      it "returns false" do
        expect(subject).to be false
      end
    end
  end

  describe '#legal_entity?' do
    subject { Entity.new(type: type).legal_entity? }

    context "when entity type is Entity::Types::LEGAL_ENTITY" do
      let(:type) { Entity::Types::LEGAL_ENTITY }

      it "returns true" do
        expect(subject).to be true
      end
    end

    context "when entity type is not Entity::Types::LEGAL_ENTITY" do
      let(:type) { Entity::Types::NATURAL_PERSON }

      it "returns false" do
        expect(subject).to be false
      end
    end
  end

  describe '#country' do
    let(:entity) { Entity.new }
    subject { entity.country }

    context "when entity is a natural person" do
      before { entity.type = Entity::Types::NATURAL_PERSON }

      context "when entity does not have a nationality" do
        before { entity.nationality = nil }

        it "returns nil" do
          expect(subject).to be_nil
        end
      end

      context "when entity has a nationality" do
        before { entity.nationality = "GB" }

        it "returns country of that nationality" do
          expect(subject).to eq(ISO3166::Country[:GB])
        end
      end
    end

    context "when entity is a legal entity" do
      before { entity.type = Entity::Types::LEGAL_ENTITY }

      context "when entity does not have a jurisdiction_code" do
        before { entity.jurisdiction_code = nil }

        it "returns nil" do
          expect(subject).to be_nil
        end
      end

      context "when entity has an unknown jurisdiction_code" do
        before { entity.jurisdiction_code = "xx" }

        it "returns nil" do
          expect(subject).to be_nil
        end
      end

      context "when entity has a jurisdiction_code" do
        before { entity.jurisdiction_code = "gb" }

        it "returns country of that jurisdiction" do
          expect(subject).to eq(ISO3166::Country[:GB])
        end
      end

      context "when entity has a jurisdiction_code with subdivision" do
        before { entity.jurisdiction_code = "gb_xx" }

        it "returns country of that jurisdiction" do
          expect(subject).to eq(ISO3166::Country[:GB])
        end
      end
    end
  end

  describe '#country_subdivision' do
    let(:entity) { Entity.new }
    subject { entity.country_subdivision }

    context "when entity is a natural person" do
      before { entity.type = Entity::Types::NATURAL_PERSON }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "when entity is a legal entity" do
      before { entity.type = Entity::Types::LEGAL_ENTITY }

      context "when entity does not have a country" do
        before { entity.jurisdiction_code = nil }

        it "returns nil" do
          expect(subject).to be_nil
        end
      end

      context "when entity does not have a subdivision code" do
        before { entity.jurisdiction_code = "gb" }

        it "returns nil" do
          expect(subject).to be_nil
        end
      end

      context "when entity has an unknown subdivision code" do
        before { entity.jurisdiction_code = "gb_xx" }

        it "returns nil" do
          expect(subject).to be_nil
        end
      end

      context "when entity has a known subdivision code" do
        before { entity.jurisdiction_code = "us_de" }

        it "returns subdivision" do
          expect(subject).to eq(ISO3166::Country[:US].subdivisions["DE"])
        end
      end
    end
  end

  describe '#country_code' do
    let(:entity) { Entity.new }

    subject { entity.country_code }

    context 'when the entity has a country' do
      before do
        allow(entity).to receive(:country).and_return(ISO3166::Country[:GB])
      end

      it 'returns the alpha2 code of the country' do
        expect(subject).to eq('GB')
      end
    end

    context 'when the entity does not have a country' do
      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end

  describe '#upsert' do
    let(:jurisdiction_code) { 'gb' }

    let(:identifier) do
      {
        'jurisdiction_code' => jurisdiction_code,
        'company_number' => '01234567',
      }
    end

    let(:name) { 'EXAMPLE LIMITED' }

    subject { Entity.new(identifiers: [identifier], name: name) }

    context 'when a document with the same identifier exists in the database' do
      before do
        @entity = Entity.create!(identifiers: [identifier], name: 'Example Limited')
      end

      it 'updates the fields of the existing document' do
        expect { subject.upsert }.to change { @entity.reload.name }.to(name)
      end

      it 'updates the id of the subject to match the existing document' do
        expect { subject.upsert }.to change { subject.id }.to(@entity.id)
      end

      it 'does not create a new document' do
        expect { subject.upsert }.not_to change { Entity.count }
      end

      context "when the new document has multiple identifiers" do
        let(:other_identifier) { { 'a' => 'b' } }
        before do
          subject.identifiers << other_identifier
        end

        it "matches existing document with any of them" do
          @entity.set(identifiers: [identifier])
          subject.upsert
          expect(@entity.reload.identifiers).to match_array([
            identifier,
            other_identifier,
          ])

          @entity.set(identifiers: [other_identifier])
          subject.upsert
          expect(@entity.reload.identifiers).to match_array([
            identifier,
            other_identifier,
          ])
        end

        context "when a second document with one of the other identifiers exists in the database" do
          before do
            Entity.create!(identifiers: [other_identifier])
          end

          it "raises an exception mentioning the identifiers" do
            expect { subject.upsert }.to raise_error(RuntimeError, /#{subject.identifiers}/)
          end
        end
      end

      context "when the existing document also has other identifiers" do
        let(:other_identifier) { { 'a' => 'b' } }
        before do
          @entity.identifiers << other_identifier
          @entity.save!
        end

        it "keeps both identifiers" do
          subject.upsert

          expect(@entity.reload.identifiers).to match_array([
            identifier,
            other_identifier,
          ])
        end
      end
    end

    context 'when no document with the same identifier exists in the database' do
      it 'creates a new document' do
        expect { subject.upsert }.to change { Entity.count }.from(0).to(1)
      end
    end

    it 'retries on duplicate key error exceptions' do
      # The findAndModify command is atomic but can potentially fail
      # due to unique index constraint violation, as documented here:
      # https://docs.mongodb.com/manual/reference/command/findAndModify/#upsert-and-unique-index

      collection = subject.collection

      allow(subject).to receive(:collection).and_return(collection)

      error = Mongo::Error::OperationFailure.new('E11000 duplicate key error collection: ...')

      expect(collection).to receive(:find_one_and_update).and_raise(error)
      expect(collection).to receive(:find_one_and_update).and_call_original

      subject.upsert
    end
  end

  describe '#to_builder' do
    subject do
      described_class.new(
        id: 1,
        type: type,
        name: 'name',
        address: 'address',
        nationality: 'British',
        country_of_residence: 'GB',
        dob: '1975-08-24',
        jurisdiction_code: 'blue',
        company_number: '123456789',
        incorporation_date: '21/08/1990',
        company_type: 'funky',
      )
    end

    context 'when a person' do
      let(:type) { Entity::Types::NATURAL_PERSON }

      it 'returns a JSON representation' do
        expect(JSON.parse(subject.to_builder.target!)).to eq(
          'id' => '1',
          'type' => Entity::Types::NATURAL_PERSON,
          'name' => 'name',
          'address' => 'address',
          'nationality' => 'British',
          'country_of_residence' => 'GB',
          'dob' => [1975, 8, 24],
        )
      end
    end

    context 'when a legal entity' do
      let(:type) { Entity::Types::LEGAL_ENTITY }

      it 'returns a JSON representation' do
        expect(JSON.parse(subject.to_builder.target!)).to eq(
          'id' => '1',
          'type' => Entity::Types::LEGAL_ENTITY,
          'name' => 'name',
          'address' => 'address',
          'jurisdiction_code' => 'blue',
          'company_number' => '123456789',
          'incorporation_date' => '1990-08-21',
          'dissolution_date' => nil,
          'company_type' => 'funky',
        )
      end
    end
  end
end
