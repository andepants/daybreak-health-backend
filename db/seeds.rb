# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Seeding database..."

# Create test therapists
therapists_data = [
  {
    first_name: "Sarah",
    last_name: "Chen",
    license_type: "LCSW",
    email: "sarah.chen@daybreakhealth.test",
    treatment_modalities: ["CBT", "DBT", "Mindfulness"],
    age_ranges: ["13-17", "18-25"],
    bio: "Dr. Chen specializes in adolescent mental health with over 10 years of experience helping teens navigate anxiety and depression.",
    appointment_duration_minutes: 50,
    buffer_time_minutes: 10,
    active: true
  },
  {
    first_name: "Michael",
    last_name: "Torres",
    license_type: "LPC",
    email: "michael.torres@daybreakhealth.test",
    treatment_modalities: ["EMDR", "Trauma-Focused CBT", "Play Therapy"],
    age_ranges: ["13-17", "18-25"],
    bio: "Dr. Torres is a licensed professional counselor specializing in trauma-informed care for adolescents and young adults.",
    appointment_duration_minutes: 50,
    buffer_time_minutes: 10,
    active: true
  },
  {
    first_name: "Emily",
    last_name: "Rodriguez",
    license_type: "LMFT",
    email: "emily.rodriguez@daybreakhealth.test",
    treatment_modalities: ["Family Systems", "CBT", "Solution-Focused"],
    age_ranges: ["13-17", "18-25"],
    bio: "Dr. Rodriguez is a licensed marriage and family therapist who works with teens and their families to improve communication and reduce anxiety.",
    appointment_duration_minutes: 50,
    buffer_time_minutes: 10,
    active: true
  }
]

therapists = therapists_data.map do |data|
  therapist = Therapist.find_or_create_by!(email: data[:email]) do |t|
    t.first_name = data[:first_name]
    t.last_name = data[:last_name]
    t.license_type = data[:license_type]
    t.treatment_modalities = data[:treatment_modalities]
    t.age_ranges = data[:age_ranges]
    t.bio = data[:bio]
    t.appointment_duration_minutes = data[:appointment_duration_minutes]
    t.buffer_time_minutes = data[:buffer_time_minutes]
    t.active = data[:active]
  end
  puts "  Created/found therapist: #{therapist.first_name} #{therapist.last_name}"
  therapist
end

# Create weekly availability for each therapist (Mon-Fri, 9am-5pm Central Time)
therapists.each do |therapist|
  # Days 1-5 = Monday through Friday
  (1..5).each do |day_of_week|
    TherapistAvailability.find_or_create_by!(
      therapist: therapist,
      day_of_week: day_of_week,
      timezone: "America/Chicago"
    ) do |avail|
      avail.start_time = Time.parse("09:00")
      avail.end_time = Time.parse("17:00")
      avail.is_repeating = true
    end
  end
  puts "  Created availability for #{therapist.first_name} #{therapist.last_name} (Mon-Fri 9am-5pm CT)"
end

# Update first existing session to assessment_complete and create a match
first_session = OnboardingSession.first
if first_session
  # Walk through the state machine transitions
  # started -> in_progress -> insurance_pending -> assessment_complete
  if first_session.started?
    first_session.update!(status: "in_progress")
  end
  if first_session.in_progress?
    first_session.update!(status: "insurance_pending")
  end
  if first_session.insurance_pending?
    first_session.update!(status: "assessment_complete")
  end
  puts "  Updated session #{first_session.id} to assessment_complete"

  # Create a therapist match for this session
  selected_therapist = therapists.first
  TherapistMatch.find_or_create_by!(onboarding_session: first_session) do |match|
    match.matched_therapists = therapists.map do |t|
      {
        therapist_id: t.id,
        full_name: "#{t.first_name} #{t.last_name}",
        license_type: t.license_type,
        treatment_modalities: t.treatment_modalities,
        match_score: rand(85..98)
      }
    end
    match.criteria_used = { treatment_modalities: ["CBT"], availability: true }
    match.processing_time_ms = 150
    match.selected_therapist_id = selected_therapist.id
  end
  puts "  Created TherapistMatch for session, selected therapist: #{selected_therapist.first_name} #{selected_therapist.last_name}"
else
  puts "  No existing sessions found - skipping match creation"
end

puts "Seeding complete!"
puts "  Therapists: #{Therapist.count}"
puts "  Availabilities: #{TherapistAvailability.count}"
puts "  Matches: #{TherapistMatch.count}"
