module BulletFactory
  include Scar

  struct BulletRepelled < Scar::Event::Event; end
  struct BulletHit < Scar::Event::Event; end

  class BulletComponent < Scar::Component
    getter :color, :sf
    property :velocity, :speed, :bounces
    RADIUS = 16

    @velocity : Vec
    @speed : Float32

    def initialize(_spawn, bounces : Int32)
      @color = SF::Color.new(Random.rand(256), Random.rand(256), Random.rand(256))
      @sf = SF::CircleShape.new(RADIUS)
      @sf.fill_color = @color
      @sf.origin = {RADIUS, RADIUS}
      @speed = Random.rand(200..350).to_f32
      @bounces = bounces
      @velocity = (Vec.new(WIDTH / 2, HEIGHT / 2) - _spawn).unit * @speed # Vec.new(Random.rand - 0.5, Random.rand - 0.5).unit * @speed
    end
  end

  class BulletSystem < Scar::System
    @elapsed = 0.0

    def update(a, s, dt)
      freq = a.score / 500.0 + 0.5
      @elapsed += dt
      if @elapsed > 1.0 / freq
        s << BulletFactory.mk_bullet((a.score / 500).floor.to_i)
        @elapsed = 0
      end

      player = s["player"]
      playerRot = player.rotation
      playerlow = (playerRot - Math::PI / 4) % (Math::PI * 2)
      playerhigh = (playerRot + Math::PI / 4) % (Math::PI * 2)

      middle = Vec.new(WIDTH / 2, HEIGHT / 2)

      # move, destroy and bounce bullets
      s.each_with BulletComponent do |e, blt|
        e.position += blt.velocity * dt
        blt.sf.position = e.position.sf

        ang = (middle - e.position).angle

        # bounce or destroy if out of bounds
        if !Rect.new(-100, -100, WIDTH + 100, HEIGHT + 100).contains?(e.position)
          if blt.bounces > 0
            blt.velocity = Vec.from_polar(ang + Random.rand - 0.5, blt.speed)
            blt.bounces -= 1
          else
            e.suicide
          end
        end

        # normalize and reverse ang to test against player
        # ang = -ang
        ang = ang + Math::PI

        # collide with player
        if e.position.dist(middle) - BulletComponent::RADIUS - 3 < 200
          if (playerlow > playerhigh && ((playerlow < ang && ang < 360) || (playerhigh > ang && ang > 0))) || (playerlow < ang && playerhigh > ang)
            blt.velocity *= -1
            a.broadcast BulletRepelled.new
          else
            a.broadcast BulletHit.new
            e.suicide
          end
        end
      end
    end

    def render(a, s, dt)
      s.each_with BulletComponent do |e, blt|
        a.window.draw(blt.sf)
      end
    end
  end

  SPAWNS = [
    Vec.new(0, 0), Vec.new(0.5, 0), Vec.new(1, 0), Vec.new(1, 0.5), Vec.new(1, 1), Vec.new(0.5, 1), Vec.new(0, 1), Vec.new(0, 0.5),
  ].map { |v| v * Vec.new(WIDTH, HEIGHT) }
  @@bullet_id = 0u32

  def self.mk_bullet(bounces)
    _spawn = SPAWNS[Random.rand(SPAWNS.size)].dup
    e = Entity.new("bullet_#{@@bullet_id}", BulletComponent.new(_spawn, bounces), position: _spawn)
    @@bullet_id += 1
    e
  end
end
