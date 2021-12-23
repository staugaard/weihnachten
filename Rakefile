# task default: ['test']

require_relative './lib/email'
require "google/apis/gmail_v1"
require "googleauth"
require "googleauth/stores/file_token_store"
require "fileutils"

##
# Ensure valid credentials, either by restoring from the saved credentials
# files or intitiating an OAuth2 authorization. If authorization is required,
# the user's default browser will be launched to approve the request.
#
# @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
def authorize
  client_id = Google::Auth::ClientId.from_file("credentials.json")
  token_store = Google::Auth::Stores::FileTokenStore.new(file: "token.yaml")
  authorizer = Google::Auth::UserAuthorizer.new(client_id, Google::Apis::GmailV1::AUTH_GMAIL_READONLY, token_store)
  user_id = "default"
  credentials = authorizer.get_credentials(user_id)
  if credentials.nil?
    url = authorizer.get_authorization_url(base_url: "urn:ietf:wg:oauth:2.0:oob")
    puts "Open the following URL in the browser and enter the " \
         "resulting code after authorization:\n" + url
    code = $stdin.gets
    credentials = authorizer.get_and_store_credentials_from_code(
      user_id: user_id, code: code, base_url: "urn:ietf:wg:oauth:2.0:oob"
    )
  end
  credentials
end

task :delete_posts do
  Dir.glob('./_posts/*').each do |path|
    FileUtils.rm(path)
  end
end

task generate: [:delete_posts] do
  Dir.glob('./emails/*.eml') do |path|
    Email.new(path).generate_post
  end
end

task :foo do
  gmail = Google::Apis::GmailV1::GmailService.new
  gmail.client_options.application_name = "Weihnachten"
  gmail.authorization = authorize

  response = gmail.list_user_messages('me', label_ids: ['Label_447071745886110511'], max_results: 500)
  response.messages.map(&:id).each do |message_id|
    path = "emails/#{message_id}.eml"
    next if File.exist?(path)
    puts "Getting message #{message_id}"
    response = gmail.get_user_message('me', message_id, format: 'raw')
    File.open(path, 'wb') do |f|
      f.write(response.raw)
    end
    Email.new(path).generate_post
  end
end

task :import do
  gmail = Google::Apis::GmailV1::GmailService.new
  gmail.client_options.application_name = "Weihnachten"
  gmail.authorization = authorize

  response = gmail.list_user_messages('me', label_ids: ['Label_6467171461303627292'], max_results: 500)
  response.messages.map(&:id).each do |message_id|
    path = "emails/#{message_id}.eml"
    next if File.exist?(path)
    puts "Getting message #{message_id}"
    response = gmail.get_user_message('me', message_id, format: 'raw')
    File.open(path, 'wb') do |f|
      f.write(response.raw)
    end
    Email.new(path).generate_post
  end
end

task :delete_gmails do
  Dir.glob('./emails/*.eml').grep(/\/[0-9a-f]+\.eml$/).each do |path|
    puts path
    FileUtils.rm(path)
  end
end
