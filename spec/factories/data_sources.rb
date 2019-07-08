FactoryGirl.define do
  factory :data_source do
    url "http://www.example.com"
    sequence(:name) { |n| "Example Source #{n}" }
    sequence(:document_id) { |n| "Source #{n}" }

    factory :psc_data_source do
      url 'http://download.companieshouse.gov.uk/en_pscdata.html'
      name 'UK PSC Register'
      document_id 'GB PSC Snapshot'
    end
  end
end
