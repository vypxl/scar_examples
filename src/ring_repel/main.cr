require "scar"
require "./main_scene.cr"

WIDTH = 900
HEIGHT = 900

class StartSystem < Scar::System
  def update(a, s, dt)
    a << mk_main_scene() if a.input.active? :Start
  end
end

class RingRepel < Scar::App
  include Scar

  property :score
  @score : Int64 = 0
  @high_score : Int64 = 0

  def init
    @window.framerate_limit = 120

    @input.bind_digital(:Closed) { Input.sf_key(:Escape) }
    @input.bind_digital(:Closed) { Input.sf_key(:Q) }
    @input.bind_digital(:Closed) { SF::Joystick.button_pressed?(0, 1) }
    @input.bind_digital(:Start)  { Input.sf_key(:Space) }

    Assets.use "assets"
    Assets.load_all

    subscribe(Event::Closed) { exit(0) }

    @score = 0

    self << mk_menu_scene()
    Music.play "ring_repel/music.ogg"
    Music.current.loop = true
    Music.current.volume = 50
  end

  def update(dt)
    broadcast(Event::Closed.new) if input.active?(:Closed)
  end

  def render(dt)
    @window.clear(SF::Color::Black)
  end

  def game_over
    pop()
    if @score > @high_score
      @high_score = @score
      scene.spaces[0]["score"][Components::Text].text = "Score: #{@score} | Highscore: #{@high_score}"
    end
  end

  def mk_menu_scene()
    sc = Scene.new
    sp = Space.new("ui")
    sc << sp
    sp << Entity.new("txt", Components::Transform.new(Vec.new(48, 96)), Components::Text.new("Press space to start!", Assets["OpenSans-Regular.ttf", Assets::Font]))
    sp << Entity.new("score", Components::Transform.new(Vec.new(48, 48)), Components::Text.new("Score: - | Highscore: -", Assets["OpenSans-Regular.ttf", Assets::Font]))
    sp << Systems::DrawTexts.new
    sp << StartSystem.new
    sc
  end
end

settings = SF::ContextSettings.new
settings.antialiasing_level = 4
window = SF::RenderWindow.new(SF::VideoMode.new(WIDTH, HEIGHT), "Ring Repel", SF::Style::Close, settings)
desktop_mode = SF::VideoMode.desktop_mode
window.position = Scar::Vec.new(desktop_mode.width - WIDTH - (desktop_mode.width / 10), desktop_mode.height / 10).sf
app = RingRepel.new(window, Scar::Input.new)
app.run
