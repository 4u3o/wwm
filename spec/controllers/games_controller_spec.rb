require 'rails_helper'
require 'support/my_spec_helper'

RSpec.describe GamesController, type: :controller do
  let(:user) { FactoryGirl.create(:user) }
  let(:admin) { FactoryGirl.create(:user, is_admin: true) }
  let(:game_w_questions) { FactoryGirl.create(:game_with_questions, user: user) }

  # группа тестов для незалогиненного юзера
  context 'Anon' do
    # Аноним не может смотреть игру
    it 'kicks from #show' do
      # Вызываем экшен
      get :show, id: game_w_questions.id
      # Проверяем ответ
      # статус ответа не равен 200
      expect(response).not_to be_ok
      # Devise должен отправить на логин
      expect(response).to redirect_to(new_user_session_path)
      # Во flash должно быть сообщение об ошибке
      expect(flash[:alert]).to be
    end

    it 'kicks from #create' do
      post :create

      expect(response).not_to be_ok
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to be
    end

    it 'kicks from #answer' do
      put :answer, id: game_w_questions.id

      expect(response).not_to be_ok
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to be
    end

    it 'kicks from #take_money' do
      put :answer, id: game_w_questions.id

      expect(response).not_to be_ok
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to be
    end
  end

  # группа тестов на экшены контроллера, доступных залогиненным юзерам
  context 'Usual user' do
    let(:another_user_game) { FactoryGirl.create(:game_with_questions) }
    let(:another_game_w_questions) { FactoryGirl.create(:game_with_questions, user: user) }

    # Этот блок будет выполняться перед каждым тестом в группе
    # Логиним юзера с помощью девайзовского метода sign_in
    before(:each) { sign_in user }

    # юзер может создать новую игру
    it 'creates game' do
      # Создадим пачку вопросов
      generate_questions(15)

      # Экшен create у нас отвечает на запрос POST
      post :create
      # Вытаскиваем из контроллера поле @game
      game = assigns(:game)

      # Проверяем состояние этой игры: она не закончена
      # Юзер должен быть именно тот, которого залогинили
      expect(game).not_to be_finished
      expect(game.user).to eq(user)
      # Проверяем, есть ли редирект на страницу этой игры
      # И есть ли сообщение об этом
      expect(response).to redirect_to(game_path(game))
      expect(flash[:notice]).to be
    end

    it 'kicks from another user\'s #show' do
      get :show, id: another_user_game.id

      expect(response).not_to be_ok
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to be
    end

    it '#show game' do
      # Показываем по GET-запросу
      get :show, id: game_w_questions.id
      # Вытаскиваем из контроллера поле @game
      game = assigns(:game)
      # Игра не закончена
      expect(game).not_to be_finished
      # Юзер именно тот, которого залогинили
      expect(game.user).to eq(user)

      # Проверяем статус ответа (200 ОК)
      expect(response).to be_ok
      # Проверяем рендерится ли шаблон show (НЕ сам шаблон!)
      expect(response).to render_template('show')
    end

    it 'cannot start another game untill old one ends' do
      game_w_questions

      expect(game_w_questions).not_to be_finished

      expect { post :create }.not_to change(Game, :count)

      expect(response).to redirect_to(game_path(game_w_questions.id))
      expect(flash[:alert]).to be
    end

    it 'answers correct' do
      # Дёргаем экшен answer, передаем параметр params[:letter]
      put :answer,
          id: game_w_questions.id,
          letter: game_w_questions.current_game_question.correct_answer_key
      game = assigns(:game)

      # Игра не закончена
      expect(game).not_to be_finished
      # Уровень больше 0
      expect(game.current_level).to be > 0

      # Редирект на страницу игры
      expect(response).to redirect_to(game_path(game))
      # Флеш пустой
      expect(flash).to be_empty
    end

    it 'takes money' do
      game_w_questions.update_attribute(:current_level, 2)

      put :take_money, id: game_w_questions.id

      game = assigns(:game)

      expect(game).to be_finished
      expect(game.check_status).to eq(:money)
      expect(game.prize).to eq(200)

      user.reload

      expect(user.balance).to eq(200)

      expect(response).to redirect_to(user_path(user))
      expect(flash[:warning]).to be
    end
  end

end
