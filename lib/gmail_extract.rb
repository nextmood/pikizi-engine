# see http://railstips.org/blog/archives/2008/10/27/using-gmail-with-imap-to-receive-email-in-rails/

require 'net/imap'
require 'net/http'
require 'rubygems'
require 'tmail'

# amount of time to sleep after each loop below
SLEEP_TIME = 60


# this script will continue running forever
#loop do
#  begin
    # make a connection to imap account
    imap = Net::IMAP.new('imap.gmail.com', '993', true)
    imap.login('cpatte@gmail.com', 'li100guai')
    # select inbox as our mailbox to process
    imap.select('Inbox')

    # get all emails that are in inbox that have not been deleted
    #  http://yardoc.com/docs/MagLev-maglev/Net/IMAP#search-instance_method
    imap.uid_search(["SINCE", "8-Mar-2010"]).each do |uid|
      source   = imap.uid_fetch(uid, ['RFC822']).first.attr['RFC822']
      email = TMail::Mail.parse(source)
      # tmail doc -> http://tmail.rubyforge.org/rdoc/index.html

      #
      # email.content_type
      # email.destinations
      # email.from_addrs
      # has_attachments?()
      # in_reply_to
      # date
      # references
      # message_id
      puts "#{email.date} uid=#{uid} message_id=#{email.message_id} content_type=#{email.content_type} from=#{email.from.inspect} references=#{email.references.inspect}"
    end

    imap.logout
    imap.disconnect

  # NoResponseError and ByResponseError happen often when imap'ing
#  rescue Net::IMAP::NoResponseError => e
#    puts "*** Net::IMAP::NoResponseError" # send to log file, db, or email
#  rescue Net::IMAP::ByeResponseError => e
#    # send to log file, db, or email
#    puts "*** Net::IMAP::ByeResponseError"
#  rescue => e
#    puts "*** error"
#    # send to log file, db, or email
#  end

  # sleep for SLEEP_TIME and then do it all over again
#  sleep(SLEEP_TIME)
#end