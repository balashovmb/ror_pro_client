require 'net/http'
require 'uri'
require 'json'
require 'oauth2'

class Client

  def initialize
    @message = ''
    @settings = YAML::load_file "settings.yml"
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
    when '9'
      options
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
    my_profile = JSON.parse(res)
    puts "Вы вошли в систему как #{my_profile['email']}"     
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
    questions = JSON.parse(res)['questions']
    questions.each do |question|
      print question['id'].to_s + ' '
      puts question['title']
    end
    press_enter
    @message = ''
  end

  def access_token
    @access_token ||= get_access_token 
  end

  def get_code
    client = OAuth2::Client.new(
      @settings['client_id'], 
      @settings['client_secret'],
      :site => @settings['site']
    )    
    puts "Перейдите по ссылке ниже и скопируйте код авторизации:"
    puts client.auth_code.authorize_url(:redirect_uri => @settings['redirect_uri'])
    puts "Вставьте код авторизации и нажмите Enter"
    @code = gets.chomp
  end

  def get_access_token
    get_code
    body = { "client_id" => @settings['client_id'],
              "client_secret" => @settings['client_secret'],
              "code" => @code,
              "grant_type" => "authorization_code",
              "redirect_uri" => @settings['redirect_uri']                
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

  def options
    puts @settings
    puts '1) Изменить client_id'
    puts '2) Изменить client_secret'
    puts '3) Изменить redirect_uri'
    puts '4) Изменить адрес сайта'
    puts '0) Выхода в основное меню'    
    user_choice = gets.chomp
    system('clear')
    case user_choice
    when '1'
      puts 'Введите client_id'
      @settings['client_id'] = gets.chomp
    when '2'
      puts 'Введите client_secret'
      @settings['client_secret'] = gets.chomp
    when '3'
      puts 'Введите redirect_uri'
      @settings['redirect_uri'] = gets.chomp      
    when '4'
      puts 'Введите адрес сайта'
      @settings['site'] = gets.chomp   
    when '0'
      main_menu
    else
      options    
    end
    save_settings  
  end

  def save_settings
    File.open("settings.yml", "w") do |file|
      file.write @settings.to_yaml
    end
  end
end

client = Client.new
client.main_menu