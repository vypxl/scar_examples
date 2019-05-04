require "scar"

WIDTH  = 1600
HEIGHT = 900

class PlayerComponent < Scar::Component
end

class PlayerSystem < Scar::System
  include Scar

  @jump_key = 0
  @can_jump = 2
  @jump1 : Tween? = nil
  @jump1_h = 0f32

  SPEED       = 800
  JUMP_HEIGHT = 500
  JUMP_TIME   = 0.8
  GROUND      = HEIGHT - 128

  def update(app, space, dt)
    player = space["player"]
    tr = player[Components::Transform]
    spr = player[Components::AnimatedSprite]

    movement = Vec.new
    movement.x += 1 if app.input.active? :Right
    movement.x -= 1 if app.input.active? :Left
    running = app.input.active? :Run
    movement *= 1.8 if running
    tr.pos += movement * SPEED * dt

    spr.state = movement == 0 ? "idle" : (running ? "run" : "walk") unless spr.state == "jump"

    tr.pos.x = WIDTH.to_f32 if tr.pos.x < 0
    tr.pos.x = 0f32 if tr.pos.x > WIDTH
    @can_jump = 2 if tr.pos.y == GROUND

    if app.input.active? :Jump
      if @jump_key == 0
        @jump_key = 1
      else
        @jump_key = 2
      end
    else
      @jump_key = 0
    end

    if @can_jump > 0 && @jump_key == 1
      @can_jump -= 1
      spr.state = "jump"
      app.act Actions::PlaySound.new(Assets["jump.wav", Assets::Sound])
      if @can_jump == 1
        @jump1 = app.tween JUMP_TIME/2, Easing::EaseOutQuad.new, ->(t : Tween) { tr.pos.y = GROUND - t.fraction * JUMP_HEIGHT; nil }, ->(t : Tween) {
          @jump1 = app.tween JUMP_TIME/2, Easing::EaseInQuad.new, ->(t : Tween) { tr.pos.y = GROUND - (JUMP_HEIGHT - t.fraction * JUMP_HEIGHT); nil }, ->(t : Tween) {
            @can_jump = 2
            @jump1 = nil
            spr.state = "idle"
            nil
          }
          nil
        }
      else
        j = @jump1
        if j
          j.paused = true
          j.abort
        end
        @jump1_h = GROUND - tr.pos.y
        app.tween JUMP_TIME/2, Easing::EaseOutQuad.new, ->(t : Tween) { tr.pos.y = GROUND - (@jump1_h + t.fraction * JUMP_HEIGHT); nil }, ->(t : Tween) {
          app.tween JUMP_TIME/2, Easing::EaseInQuad.new, ->(t : Tween) { tr.pos.y = GROUND - (@jump1_h + JUMP_HEIGHT - t.fraction * (@jump1_h + JUMP_HEIGHT)); nil }, ->(t : Tween) {
            @can_jump = 2
            @jump1 = nil
            spr.state = "idle"
            nil
          }
          nil
        }
      end
    end

  end
end

class FPSSystem < Scar::System
    include Scar

    def update(app, space, dt)
        space["fps_counter"][Components::Text].text = "FPS: #{(1 / dt).round 1}"
    end
end

class ExitHandling < Scar::System
  include Scar

  def update(a, s, dt)
    a.broadcast(Event::Closed.new) if a.input.active?(:Closed)
    s["img"].suicide if a.input.active?(:Kill) && s["img"]?
  end
end

class JumpingSquare < Scar::App
  include Scar

  def init
    @window.position = Vec.new(window.position.x + 100, 100).sf
    @window.framerate_limit = 120

    @input.bind_digital(:Closed) { Input.sf_key(:Escape) }
    @input.bind_digital(:Closed) { Input.sf_key(:Q) }
    @input.bind_digital(:Closed) { SF::Joystick.button_pressed?(0, 1) }

    @input.bind_digital(:Left) { Input.sf_key(:Left) }
    @input.bind_digital(:Right) { Input.sf_key(:Right) }
    @input.bind_digital(:Left) { Input.sf_key(:A) }
    @input.bind_digital(:Right) { Input.sf_key(:D) }
    @input.bind_digital(:Run) { Input.sf_key(:LShift) }
    @input.bind_digital(:Jump) { Input.sf_key(:Space) }

    @input.bind_digital(:Left) { SF::Joystick.get_axis_position(0, SF::Joystick::X) < 0 }
    @input.bind_digital(:Right) { SF::Joystick.get_axis_position(0, SF::Joystick::X) > 0 }
    @input.bind_digital(:Run) { SF::Joystick.button_pressed?(0, 2) }
    @input.bind_digital(:Jump) { SF::Joystick.button_pressed?(0, 0) }

    @input.bind_digital(:Kill) { Input.sf_key(:K) }

    subscribe(Event::Closed) { Logger.debug "exit"; exit() }

    Assets.use "assets"
    # Assets.cache_zipfile "assets.zip"
    Assets.load_all

    self << Scene.new(
      Space.new("background", Systems::DrawSprites.new, z: 0),
      Space.new(
        "main",
        ExitHandling.new,
        PlayerSystem.new,
        Systems::DrawSprites.new,
        Systems::AnimateSprites.new,
        z: 1
      ),
      Space.new("ui",
        Systems::DrawTexts.new,
        FPSSystem.new,
        z: 2
      )
    )


    # Background
    background = Components::Sprite.new(Assets["nested/background.png", Assets::Texture])
    background_tex = background.sf.texture
    background.sf.scale = (Vec.new(WIDTH, HEIGHT) / Vec.from(background_tex.size)).sf if background_tex.is_a? SF::Texture
    scene["background"] << Entity.new("background",
      Components::Transform.new(Vec.new 0, 0),
      background
    )

    # Player
    anspr = Components::AnimatedSprite.new(
      Assets["spritesheet.png", Assets::Texture],
      {128, 128},
      {"idle" => {0, 4, 4}, "walk" => {0, 4, 8}, "run" => {0, 4, 16}, "jump" => {8, 8, 16}}
    )
    anspr.state = "idle"

    player = Entity.new("player",
      Components::Transform.new(Vec.new 500, PlayerSystem::GROUND),
      anspr,
      PlayerComponent.new
    )
    scene["main"] << player

    # Sample text
    scene["ui"] << Entity.new("text",
      Components::Transform.new(Vec.new 400, 100),
      Components::Text.new(
        Assets["text.txt", Assets::Text],
        Assets["OpenSans-Regular.ttf", Assets::Font]
      )
    )

    # FPS counter
    scene["ui"] << Entity.new("fps_counter",
        Components::Transform.new(Vec.new 10, 10),
        Components::Text.new(
            "FPS: 0",
            Assets["OpenSans-Regular.ttf", Assets::Font]
        )
    )


    act TimedAction.new(5, -> { Logger.info "hi after 5 seconds" })

    Music.play("music.ogg")
    Music.current.loop = true
    Music.current.volume = 30
  end

  def update(dt)
  end

  def render(dt)
    @window.clear(SF::Color::Black)
  end
end

window = SF::RenderWindow.new(SF::VideoMode.new(WIDTH, HEIGHT), "Test", SF::Style::Close)

app = JumpingSquare.new(window, Scar::Input.new)
app.run
