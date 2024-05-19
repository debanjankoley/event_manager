require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,"0")[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def clean_phone_number(phone_number)
  if phone_number.to_s.size == 10
    phone_number.to_s
  elsif phone_number.to_s == 11
    phone_number.to_s[0] == "1" ? phone_number.to_s[1..-1] : "0000000000"
  else
    "0000000000"
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

no_of_regs_at_hours = Hash.new(0)
reg_days = Array.new
contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id,form_letter)

  reg_date = row[:regdate]
  reg_hour = Time.strptime(reg_date, "%m/%d/%Y %k:%M").hour.to_s + ":00"
  no_of_regs_at_hours[reg_hour] += 1

  reg_day = Date.strptime(reg_date, "%m/%d/%Y %k:%M").wday
  reg_days << reg_day
end

def time_targeting(reg_hours)
  sorted_hash = reg_hours.sort_by { |k,v| -v }
  peak_hours = []
  sorted_hash.each { |k,v| peak_hours << k if v == sorted_hash.first[1] }
  puts "Peak registration hours -- #{peak_hours.join(", ")}."
end

def day_targeting(reg_days)
  weekdays = {0=>"Sunday", 1=>"Monday", 2=>"Tuesday", 3=>"Wednesday", 4=>"Thursday", 5=>"Friday", 6=>"Saturday"}
  days_hash = Hash.new(0)
  reg_days.each { |day| days_hash[day] += 1 }
  sorted_hash = days_hash.sort_by{ |k,v| -v }
  peak_days_num = []
  peak_days = []
  sorted_hash.each { |k,v| peak_days_num << k if v == sorted_hash.first[1] }
  peak_days_num.each { |num| peak_days << weekdays[num] }
  puts "Peak registration days -- #{peak_days.join(", ")}."
end

time_targeting(no_of_regs_at_hours)
day_targeting(reg_days)
