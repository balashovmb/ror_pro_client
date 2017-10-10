require 'net/http'
require 'uri'
require 'json'
require 'oauth2'

class Client

  def initialize
    @client_id     = "aba4ddd63d81ad3d538875a7ee9f97f4de1efd20b82604b15388edae6eb63842"
    @client_secret = "d5ddf868b8bed1f6568092e849808469b4b3cc85042bfe94a9d8a971ee111d93"
    @redirect_uri  = "urn:ietf:wg:oauth:2.0:oob"
    @site          = "http://localhost:3000" # your provider server, mine is running on localhost
    @message = ''
  end  

  def main_menu
    loop do
      system('clear')
      text_path = File.expand_path('../menu_text', __FILE__)
      puts File.read(text_path)
      puts @message
      menu_input
    end
  end

  private

  def menu_input
    print 'Ваш выбор: '
    user_choice = gets.chomp
    system('clear')
    case user_choice
    when '1'
      get_my_profile
    when '2'
      get_questions_list
    when '0'
      exit
    else
      @message = 'Некорректный ввод'
    end
  end

  def get_my_profile
    addr = 'http://localhost:3000/api/v1/profiles/me.json?access_token=' + access_token
    uri = URI(addr)
    res = Net::HTTP.get(uri)
    puts res
    my_hash = JSON.parse(res)
    puts my_hash
    puts my_hash['email']     
    press_enter
  rescue TypeError
    puts 'Неверный код авторизации'
    press_enter
    retry    
  end
  
  def get_questions_list
    return @message = "Вы не авторизованы" unless @access_token  
    addr = 'http://localhost:3000/api/v1/questions.json?access_token=' + access_token
    uri = URI(addr)
    res = Net::HTTP.get(uri)
    puts res
    press_enter
    @message = ''
  end

  def access_token
    @access_token ||= get_access_token 
  end

  def get_code
    client = OAuth2::Client.new(@client_id, @client_secret, :site => @site)
    puts "Перейдите по ссылке ниже и скопируйте код авторизации:"
    puts client.auth_code.authorize_url(:redirect_uri => @redirect_uri)
    puts "Вставьте код авторизации и нажмите Enter"
    @code = gets.chomp
  end

  def get_access_token
    get_code
    body = { "client_id" => @client_id,
              "client_secret" => @client_secret,
              "code" => @code,
              "grant_type" => "authorization_code",
              "redirect_uri" => @redirect_uri                
            }.to_json
    res = Net::HTTP.post URI('http://localhost:3000/oauth/token'),
                         body,
                         "Content-Type" => "application/json"
    res_hash = JSON.parse(res.body)
    @access_token = res_hash["access_token"]
  end

  def press_enter
    puts "Для продолжения нажмите Enter"
    gets
  end
end

client = Client.new
client.main_menu