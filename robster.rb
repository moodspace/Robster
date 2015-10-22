require 'open-uri'
require 'nokogiri'
require 'json'

module Terms
  WI = 0
  SP = 1
  SU = 2
  FA = 3
end

def compareTerm(fromTerm, fromYear, toTerm, toYear)
  if fromYear == toYear and fromTerm == toTerm
    return 0
  end
  return (fromYear > toYear or (fromYear == toYear and fromTerm > toTerm)) ? 1 : -1
end

def termInRange(term, year, fromTerm, fromYear, toTerm, toYear)
  return (compareTerm(fromTerm, fromYear, term, year) <= 0 \
      and compareTerm(toTerm, toYear, term, year) >= 0)
end

def fetchRoster(fromTerm, fromYear, toTerm, toYear)
  if compareTerm(fromTerm, fromYear, toTerm, toYear) > 0
    exit
  end

  (fromYear..toYear).each do |year|
    # if WI is included
    if termInRange(Terms::WI, year, fromTerm, fromYear, toTerm, toYear)
      # puts year.to_s + 'WI'
      fetchTerm('WI', year.to_s)
    end
    # if SP is included
    if termInRange(Terms::SP, year, fromTerm, fromYear, toTerm, toYear)
      # puts year.to_s + 'SP'
      fetchTerm('SP', year.to_s)
    end
    # if SU is included
    if termInRange(Terms::SU, year, fromTerm, fromYear, toTerm, toYear)
      # puts year.to_s + 'SU'
      fetchTerm('SU', year.to_s)
    end
    # if FA is included
    if termInRange(Terms::FA, year, fromTerm, fromYear, toTerm, toYear)
      # puts year.to_s + 'FA'
      fetchTerm('FA', year.to_s)
    end
  end
end

def fetchTerm(term, year)
  subjects = fetchTermPage(term, year)
  subjectsHash = Hash.new { |hash, key| hash[key] = Hash.new }
  subjects.each do |subject|
    courses = fetchSubjectPage(subject, term, year)[1]
    coursesHash = Hash.new { |hash, key| hash[key] = Array.new }
    courses.each do |code|
      coursesHash[code] = fetchCoursePage(subject, code, term, year)
    end
    subjectsHash[subject] = coursesHash
  end

  # output as json
  File.open(term + year + '.json','w') do |f|
    f.write(subjectsHash.to_json)
  end
end

# return a list of subjects
def fetchTermPage(term, year)
  puts term + year # progress
  subjects = []
  doc = Nokogiri::HTML(open('https://classes.cornell.edu/browse/roster/' + term \
    + year))
  doc.xpath('//li[@class = "browse-subjectcode"]/a').each do |subject|
    subjects << subject.text
  end
  return subjects
end

# return a list of courses
def fetchSubjectPage(subject, term, year)
  puts "\t" + subject + term + year # progress
  courses = []
  doc = Nokogiri::HTML(open('https://classes.cornell.edu/browse/roster/' + term \
   + year + '/subject/' + subject))
  doc.xpath('//div[@class = "node"]').each do |node|
    courseSubj = node.attr('data-subject')
    courseCode = node.attr('data-catalog-nbr')
    if courseSubj.empty? or courseCode.empty?
      next
    end
    courses << courseCode
  end
  return [subject, courses]
end

# return a tuple of course title and description
def fetchCoursePage(subject, code, term, year)
  puts "\t\t" + subject + code + term + year # progress
  doc = Nokogiri::HTML(open('https://classes.cornell.edu/browse/roster/' + term \
    + year + '/class/' + subject + '/' + code))
  node = doc.xpath('//div[@class = "node"]')[1]
  courseTitle = node.xpath('h3/div[@class = "title-coursedescr"]/a').text
  courseDescr = node.xpath('p[@class = "catalog-descr"]').text
  courseGroups = node.xpath('div[@class = "sections alwaysdisplay"]/div[@class = "group heavy-left"]')
  courseGroupsArray = []
  courseGroups.each do |group|
    courseSectionsArray = []
    group.xpath('ul').each do |section|
      sectionHash = Hash.new { |hash, key| hash[key] = Hash.new }

      meta = section.xpath('li[@class = "class-numbers"]/p')
      metaHash = Hash.new { |hash, key| hash[key] = '' }
      metaHash['number'] = meta.children[0].text
      metaHash['type'] = meta.children[2].text
      metaHash['index'] = meta.children[3].text.strip
      sectionHash['meta'] = metaHash

      meeting = section.xpath('li[@class = "meeting-pattern"]/ul')
      meetingHash = Hash.new { |hash, key| hash[key] = '' }
      meetingHash['pattern'] = meeting.children[0].xpath('span/span/span').text
      meetingHash['time'] = meeting.children[0].xpath('span/time').text
      meetingHash['location'] = meeting.children[0].xpath('a[@class = "facility-search"]').text
      meetingHash['organizers'] = meeting.children[2].xpath('p/span').map { |e| e.text }
      sectionHash['meeting'] = meetingHash

      courseSectionsArray << sectionHash
    end
    courseGroupsArray << courseSectionsArray
  end

  return { 'title' => courseTitle.strip, 'description' => courseDescr.strip, 'groups' => courseGroupsArray}
end

fetchRoster(Terms::FA, 14, Terms::SP, 16)
