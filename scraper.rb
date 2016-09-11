require 'scraperwiki'
require 'mechanize'
require 'uri'
require 'logger'

@logger = Logger.new(STDOUT)

starting_url = URI('http://www.cockburn.wa.gov.au')
starting_url.path = '/News/Community_Consultation/'

comment_url = URI('http://www.cockburn.wa.gov.au/OnlineSubmissions')

class String
  def is_da?
    !self.match(/development application/).nil?
  end
end

@agent = Mechanize.new

doc = @agent.get(starting_url.to_s)
selector = 'div#Content > ol > li'
# http://www.cockburn.wa.gov.au/templates/template48/summary.asp?TemplateID=48&EventID=4142

doc.search(selector).each do |e|
  if e.inner_html.is_da?
    link = e.search('a')
    if link.attr('href').to_s =~ /Javascript:sum\('(\d+)'\)/
      record = {}

      record['council_reference'] = $1
      @logger.info("Using #{record['council_reference']} as council_reference")

      starting_url.path = '/templates/template48/summary.asp'
      starting_url.query = "TemplateID=48&EventID=#{record['council_reference']}"

      record['info_url'] = starting_url.to_s

      @logger.debug("Fetching #{record['info_url']}")

      da_doc = @agent.get(record['info_url'])

      record['address'] = da_doc.xpath("//th[text()='Name: ']/following-sibling::th").inner_html.strip + ", WA"
      @logger.info("Using #{record['address']} as address")

      description_html = da_doc.xpath("//table/tr/th/p[contains(., 'Description:')]/parent::th/following-sibling::td").inner_html
      description_text = description_html.gsub(/<br>/, "")
      record['description'] = description_text.match(/^(.*)The plans can be viewed/m)[1]

      record['date_scraped']  = Date.today.to_s
      if (ScraperWiki.select("* from data where `council_reference`='#{record['council_reference']}'").empty? rescue true)
        ScraperWiki.save_sqlite(['council_reference'], record)
      else
        puts "Skipping already saved record " + record['council_reference']
      end
    else
      @logger.info("#{link.attr('href')} doesn't look like a link to a DA page")
    end
  else
    @logger.info("Skipping #{e.search('a').inner_html} because it don't look like a DA")
  end
end
