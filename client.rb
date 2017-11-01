require 'net/http'
require 'uri'
require 'json'
require 'oauth2'

class Client
  def initialize(settings = load_settings)
    @message = ''
    @settings = settings
  end

  def main_menu
    loop do
      system 'clear'
      text_path = File.expand_path('../menu_text', __FILE__)
      puts File.read text_path
      puts @message
      menu_input
    end
  end

  private

  def load_settings
    YAML.load_file 'settings.yml'
  end

  def menu_input
    print 'Ваш выбор: '
    user_choice = gets.chomp
    system 'clear'
    case user_choice
    when '1'
      log_in
    when '2'
      questions
    when '3'
      create_question
    when '9'
      options
    when '0'
      exit
    else
      @message = 'Некорректный ввод'
    end
  end

  def log_in
    get_access_token
    return unless @access_token
    profile = load_profile
    show_profile(profile)
  end

  def load_profile
    uri = create_uri '/api/v1/profiles/me.json'
    Net::HTTP.get uri
  end

  def show_profile(profile)
    my_profile = JSON.parse profile
    press_enter "Вы вошли в систему как #{my_profile['email']}"
  end

  def questions
    return @message = 'Вы не авторизованы' unless @access_token
    questions = load_questions
    question_ids = aggregate_question_ids questions
    question_id = choose_question(questions, question_ids)
    question_json = load_question question_id
    show_full_question question_json
  end

  def choose_question(questions, question_ids)
    loop do
      system 'clear'
      show_questions questions
      puts 'Введите id вопроса, чтобы увидеть подробности. Введите 0 для выхода в главное меню'
      question_id = gets.chomp
      return if question_id == '0'
      break question_id if question_ids.include? question_id
      press_enter 'Не верный id вопроса'
    end
  end

  def load_question(question_id)
    uri = create_uri "/api/v1/questions/#{question_id}.json"
    Net::HTTP.get uri
  end

  def show_full_question(question_json)
    system 'clear'
    question = JSON.parse(question_json)['question']
    show_question question
    show_comments question
    show_attachments question
    press_enter
  end

  def show_question(question)
    puts "Заголовок: #{question['title']}"
    puts "Текст вопроса: #{question['body']}"
  end

  def show_comments(item)
    puts 'Комментарии:'
    item['comments'].each do |comment|
      print comment['id'].to_s + ' '
      puts comment['body']
    end
  end

  def show_attachments(item)
    puts 'Вложения:'
    item['attachments'].each do |attachment|
      print attachment['id'].to_s + ' '
      puts @settings['site'] + attachment['url']
    end
  end

  def load_questions
    uri = create_uri '/api/v1/questions.json'
    res = Net::HTTP.get uri
    JSON.parse(res)['questions']
  end

  def show_questions(questions)
    questions.each do |question|
      print question['id'].to_s + ' '
      puts question['title']
    end
  end

  def aggregate_question_ids(questions)
    question_ids = []
    questions.each { |question| question_ids << question['id'].to_s }
    question_ids
  end

  def get_code
    client = OAuth2::Client.new(
      @settings['client_id'],
      @settings['client_secret'],
      site: @settings['site']
    )
    puts 'Перейдите по ссылке ниже и скопируйте код авторизации:'
    puts client.auth_code.authorize_url(redirect_uri: @settings['redirect_uri'])
    puts 'Вставьте код авторизации и нажмите Enter'
    gets.chomp
  end

  def get_access_token
    code = get_code
    body = { 'client_id' => @settings['client_id'],
             'client_secret' => @settings['client_secret'],
             'code' => code,
             'grant_type' => 'authorization_code',
             'redirect_uri' => @settings['redirect_uri'] }.to_json
    uri = create_uri('/oauth/token', nil)
    res = Net::HTTP.post uri,
                         body,
                         'Content-Type' => 'application/json'
    res_hash = JSON.parse res.body
    return press_enter 'Не верный код авторизации' if res_hash.key? 'error'
    @access_token = res_hash['access_token']
  end

  def press_enter(message = nil)
    puts message if message
    puts 'Для продолжения нажмите Enter'
    gets
  end

  def create_uri(uri_pattern, token = @access_token)
    addr = @settings['site'] + uri_pattern + '?access_token='
    addr += token if token
    URI addr
  end

  def options
    show_settings
    puts <<~MENU_OPTIONS
      Введите номер желаемого действия и нажмите Enter:
      1) Изменить client_id
      2) Изменить client_secret
      3) Изменить redirect_uri
      4) Изменить адрес сайта
      0) Выход в основное меню
    MENU_OPTIONS
    user_choice = gets.chomp
    system 'clear'
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
    File.open('settings.yml', 'w') do |file|
      file.write @settings.to_yaml
    end
  end

  def show_settings
    puts <<~CURRENT_SETTINGS
      Текущие настройки:
      client_id: #{@settings['client_id']}
      client_secret: #{@settings['client_secret']}
      redirect_uri: #{@settings['redirect_uri']}
      адрес сайта: #{@settings['site']}

    CURRENT_SETTINGS
  end

  def create_question
    return @message = 'Вы не авторизованы' unless @access_token
    puts 'Введите заголовок вопроса'
    question_title = gets.chomp
    puts 'Введите тело вопроса'
    question_body = gets.chomp
    uri = create_uri '/api/v1/questions.json', nil
    body = { 'question' => { 'body' => question_body, 'title' => question_title },
             'access_token' => @access_token }.to_json
    res = Net::HTTP.post uri,
                         body,
                         'Content-Type' => 'application/json'
    res_hash = JSON.parse res.body
    if res_hash.key? 'errors'
      puts 'Во время создания вопроса произошли следующие ошибки:'
      puts res_hash['errors']
    else
      puts 'Ваш вопрос создан'
    end
    press_enter
  end
end

client = Client.new
client.main_menu
