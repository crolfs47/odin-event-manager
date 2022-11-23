require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  phone_number = phone_number.scan(/\d/).join
  if phone_number.length == 10
    phone_number
  elsif phone_number.length == 11 && phone_number[0] == '1'
    phone_number[1..10]
  else 
    'Bad number'
  end
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def find_hour(reg_date)
  Time.strptime(reg_date, '%m/%d/%y %k:%M').hour
end

def find_day(reg_date)
  Time.strptime(reg_date, '%m/%d/%y %k:%M').wday
end

def tally_amounts(array, type)
  tally_hash = Hash[array.tally.sort_by{|key, value| value}.reverse]
  tally_hash.each do |key, value|
    if type == 'day'
      puts "#{type.capitalize}: #{Date::DAYNAMES[key]}, # of Registrants: #{value}"
    else
      puts "#{type.capitalize}: #{key}, # of Registrants: #{value}"
    end
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

reg_hours = []
reg_days = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(row[:zipcode])
  phone_number = clean_phone_number(row[:homephone])

  reg_hours.push(find_hour(row[:regdate]))
  reg_days.push(find_day(row[:regdate]))

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

puts "Peak Registration Hours"
tally_amounts(reg_hours, 'hour')

puts "Peak Registration Days"
tally_amounts(reg_days, 'day')