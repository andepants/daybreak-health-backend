# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Child, type: :model do
  # AC 3.7.1, 3.7.9: Test child model with required fields and associations
  describe 'associations' do
    it { should belong_to(:onboarding_session) }
  end

  describe 'validations' do
    # AC 3.7.1: Required fields validation
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
    it { should validate_presence_of(:date_of_birth) }
    it { should validate_presence_of(:onboarding_session) }

    # AC 3.7.1: Gender is optional (no validation)
    it 'allows gender to be nil' do
      child = build(:child, gender: nil)
      expect(child).to be_valid
    end

    # AC 3.7.2: School information is optional
    it 'allows school_name and grade to be nil' do
      child = build(:child, school_name: nil, grade: nil)
      expect(child).to be_valid
    end

    # AC 3.7.10: DOB validation - not in future
    describe 'date_of_birth_not_in_future' do
      it 'rejects future dates' do
        child = build(:child, date_of_birth: 1.day.from_now.to_date.to_s)
        expect(child).not_to be_valid
        expect(child.errors[:date_of_birth]).to include('cannot be in the future')
      end

      it 'accepts past dates within valid age range' do
        child = build(:child, date_of_birth: 10.years.ago.to_date.to_s)
        expect(child).to be_valid
      end
    end

    # AC 3.7.5, 3.7.10: Age within service range (5-18)
    describe 'age_within_service_range' do
      it 'rejects children under 5 years old' do
        dob = 4.years.ago.to_date.to_s
        child = build(:child, date_of_birth: dob)
        expect(child).not_to be_valid
        expect(child.errors[:date_of_birth]).to include('child must be between 5-18 years old for Daybreak services')
      end

      it 'accepts children exactly 5 years old' do
        # Date that guarantees the child is 5 (5 years and 1 day ago)
        dob = (5.years.ago - 1.day).to_date.to_s
        child = build(:child, date_of_birth: dob)
        expect(child).to be_valid
      end

      it 'accepts children within age range (10 years old)' do
        dob = 10.years.ago.to_date.to_s
        child = build(:child, date_of_birth: dob)
        expect(child).to be_valid
      end

      it 'accepts children exactly 18 years old' do
        dob = 18.years.ago.to_date.to_s
        child = build(:child, date_of_birth: dob)
        expect(child).to be_valid
      end

      it 'rejects children over 18 years old' do
        # Use a date that ensures child is definitely over 18
        dob = (Date.today - 19.years - 1.day).to_s
        child = build(:child, date_of_birth: dob)
        expect(child).not_to be_valid
        expect(child.errors[:date_of_birth]).to include('child must be between 5-18 years old for Daybreak services')
      end
    end
  end

  # AC 3.7.8: Age calculation
  describe '#age' do
    it 'calculates age correctly from date_of_birth' do
      # Use a date that ensures exactly 10 years old
      dob = (Date.today - 10.years - 1.day)
      child = build(:child, date_of_birth: dob.to_s)
      expect(child.age).to eq(10)
    end

    it 'returns nil when date_of_birth is nil' do
      child = Child.new(date_of_birth: nil)
      expect(child.age).to be_nil
    end

    it 'handles various date formats' do
      child = build(:child, date_of_birth: '2015-03-15')
      expect(child.age).to be_a(Integer)
      expect(child.age).to be >= 9
    end

    it 'calculates age for edge case birthdays' do
      dob = 7.years.ago.to_date
      child = build(:child, date_of_birth: dob.to_s)
      expect(child.age).to be_between(6, 7)
    end
  end

  # AC 3.7.3, 3.7.4: Test encryption of PHI fields
  describe 'PHI encryption' do
    let(:child) do
      create(:child,
             first_name: 'Jane',
             last_name: 'Doe',
             date_of_birth: '2010-05-15',
             primary_concerns: 'Anxiety and trouble sleeping',
             medical_history: { medications: ['None'], diagnoses: [], hospitalizations: [] }.to_json)
    end

    it 'encrypts first_name field' do
      raw_value = ActiveRecord::Base.connection.execute(
        "SELECT first_name FROM children WHERE id = '#{child.id}'"
      ).first['first_name']
      expect(raw_value).not_to eq('Jane')
      expect(raw_value).to be_present
    end

    it 'decrypts first_name field when accessed' do
      expect(child.first_name).to eq('Jane')
    end

    it 'encrypts last_name field' do
      raw_value = ActiveRecord::Base.connection.execute(
        "SELECT last_name FROM children WHERE id = '#{child.id}'"
      ).first['last_name']
      expect(raw_value).not_to eq('Doe')
      expect(raw_value).to be_present
    end

    it 'decrypts last_name field when accessed' do
      expect(child.last_name).to eq('Doe')
    end

    it 'encrypts date_of_birth field' do
      raw_value = ActiveRecord::Base.connection.execute(
        "SELECT date_of_birth FROM children WHERE id = '#{child.id}'"
      ).first['date_of_birth']
      expect(raw_value).not_to eq('2010-05-15')
      expect(raw_value).to be_present
    end

    it 'decrypts date_of_birth when accessed' do
      expect(child.date_of_birth).to eq('2010-05-15')
    end

    it 'encrypts primary_concerns in database' do
      raw_value = ActiveRecord::Base.connection.execute(
        "SELECT primary_concerns FROM children WHERE id = '#{child.id}'"
      ).first['primary_concerns']
      expect(raw_value).not_to include('Anxiety')
      expect(raw_value).to be_present
    end

    it 'encrypts medical_history in database' do
      raw_value = ActiveRecord::Base.connection.execute(
        "SELECT medical_history FROM children WHERE id = '#{child.id}'"
      ).first['medical_history']
      expect(raw_value).not_to include('medications')
      expect(raw_value).to be_present
    end

    it 'decrypts values when accessed through model' do
      reloaded_child = Child.find(child.id)
      expect(reloaded_child.first_name).to eq('Jane')
      expect(reloaded_child.last_name).to eq('Doe')
      expect(reloaded_child.date_of_birth).to eq('2010-05-15')
      expect(reloaded_child.primary_concerns).to eq('Anxiety and trouble sleeping')
    end
  end

  # AC 3.7.4: Medical history as structured JSON
  describe 'medical history handling' do
    let(:medical_history_data) do
      {
        'medications' => ['Zoloft 25mg'],
        'diagnoses' => ['Generalized Anxiety Disorder'],
        'hospitalizations' => []
      }
    end

    it 'stores medical history as JSON text' do
      child = create(:child, medical_history: medical_history_data.to_json)
      expect(child.medical_history).to be_a(String)
      expect(child.parsed_medical_history).to eq(medical_history_data)
    end

    it 'parses medical history from JSON' do
      child = create(:child, medical_history: medical_history_data.to_json)
      parsed = child.parsed_medical_history
      expect(parsed['medications']).to eq(['Zoloft 25mg'])
      expect(parsed['diagnoses']).to eq(['Generalized Anxiety Disorder'])
      expect(parsed['hospitalizations']).to eq([])
    end

    it 'returns nil for blank medical history' do
      child = create(:child, medical_history: nil)
      expect(child.parsed_medical_history).to be_nil
    end

    it 'handles invalid JSON gracefully' do
      child = build(:child)
      child.medical_history = 'invalid json'
      child.save(validate: false)
      expect(child.parsed_medical_history).to be_nil
    end

    it 'sets medical history from hash' do
      child = build(:child)
      child.set_medical_history(medical_history_data)
      expect(child.medical_history).to be_a(String)
      expect(JSON.parse(child.medical_history)).to eq(medical_history_data)
    end
  end

  describe 'UUID primary key' do
    it 'generates UUID for id' do
      child = create(:child)
      expect(child.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end
  end

  describe 'timestamps' do
    it 'sets created_at and updated_at' do
      child = create(:child)
      expect(child.created_at).to be_present
      expect(child.updated_at).to be_present
    end
  end
end
