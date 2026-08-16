import KithCore
import SwiftUI

@MainActor
final class BubbleWorld {
    struct Body: Identifiable {
        var person: Person
        var position: CGPoint
        var velocity: CGVector
        var radius: CGFloat
        var phase: CGFloat
        var id: UUID { person.id }
    }

    var bodies: [Body] = []
    private var lastTime: Date?
    private var lastSize: CGSize = .zero

    func reconcile(people: [Person], in size: CGSize) {
        guard size.width > 8, size.height > 8 else { return }
        let resized = lastSize != size
        lastSize = size
        let remaining = Set(people.map(\.id))
        bodies.removeAll { !remaining.contains($0.person.id) }

        for person in people {
            let radius = CGFloat(person.lanternDiameter / 2)
            if let index = bodies.firstIndex(where: { $0.person.id == person.id }) {
                bodies[index].person = person
                bodies[index].radius = radius
            } else {
                bodies.append(
                    Body(
                        person: person,
                        position: Self.spawn(in: size, radius: radius, existing: bodies),
                        velocity: CGVector(
                            dx: CGFloat.random(in: -8...8),
                            dy: CGFloat.random(in: -8...8)
                        ),
                        radius: radius,
                        phase: CGFloat.random(in: 0...(2 * .pi))
                    )
                )
            }
        }

        if resized {
            for index in bodies.indices {
                bodies[index].position = Self.clamp(
                    bodies[index].position,
                    radius: bodies[index].radius,
                    in: size
                )
            }
        }
    }

    func step(now: Date, in size: CGSize, animated: Bool) {
        reconcile(people: bodies.map(\.person), in: size)
        guard animated, size.width > 8, size.height > 8 else {
            lastTime = now
            separate(in: size)
            return
        }

        let raw = now.timeIntervalSince(lastTime ?? now)
        lastTime = now
        let dt = CGFloat(min(max(raw, 0), 1 / 20))
        guard dt > 0 else { return }

        let center = CGPoint(x: size.width / 2, y: size.height * 0.52)
        for index in bodies.indices {
            var body = bodies[index]
            body.phase += dt * 0.35
            let wander = CGVector(
                dx: cos(body.phase + CGFloat(index)) * 18,
                dy: sin(body.phase * 0.9) * 14
            )
            let toCenter = CGVector(
                dx: (center.x - body.position.x) * 0.18,
                dy: (center.y - body.position.y) * 0.18
            )
            body.velocity.dx += (wander.dx + toCenter.dx) * dt
            body.velocity.dy += (wander.dy + toCenter.dy) * dt
            bodies[index] = body
        }

        separate(in: size)

        for index in bodies.indices {
            var body = bodies[index]
            let speed = hypot(body.velocity.dx, body.velocity.dy)
            let cap: CGFloat = 42
            if speed > cap {
                body.velocity.dx = body.velocity.dx / speed * cap
                body.velocity.dy = body.velocity.dy / speed * cap
            }
            body.velocity.dx *= 0.94
            body.velocity.dy *= 0.94
            body.position.x += body.velocity.dx * dt
            body.position.y += body.velocity.dy * dt
            body.position = Self.clamp(body.position, radius: body.radius, in: size)
            bodies[index] = body
        }
    }

    private func separate(in size: CGSize) {
        guard bodies.count > 1 else { return }
        for i in 0..<bodies.count {
            for j in (i + 1)..<bodies.count {
                let delta = CGVector(
                    dx: bodies[j].position.x - bodies[i].position.x,
                    dy: bodies[j].position.y - bodies[i].position.y
                )
                let distance = max(0.001, hypot(delta.dx, delta.dy))
                let minDistance = bodies[i].radius + bodies[j].radius + 16
                if distance < minDistance {
                    let overlap = (minDistance - distance) / 2
                    let nx = delta.dx / distance
                    let ny = delta.dy / distance
                    bodies[i].position.x -= nx * overlap
                    bodies[i].position.y -= ny * overlap
                    bodies[j].position.x += nx * overlap
                    bodies[j].position.y += ny * overlap
                    bodies[i].position = Self.clamp(bodies[i].position, radius: bodies[i].radius, in: size)
                    bodies[j].position = Self.clamp(bodies[j].position, radius: bodies[j].radius, in: size)
                }
            }
        }
    }

    private static func spawn(in size: CGSize, radius: CGFloat, existing: [Body]) -> CGPoint {
        for _ in 0..<16 {
            let point = CGPoint(
                x: CGFloat.random(in: (radius + 24)...max(radius + 25, size.width - radius - 24)),
                y: CGFloat.random(in: (radius + 80)...max(radius + 81, size.height - radius - 96))
            )
            let clear = existing.allSatisfy { hypot($0.position.x - point.x, $0.position.y - point.y) > $0.radius + radius + 12 }
            if clear { return point }
        }
        return CGPoint(x: size.width / 2, y: size.height / 2)
    }

    private static func clamp(_ point: CGPoint, radius: CGFloat, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(point.x, radius + 12), max(radius + 12, size.width - radius - 12)),
            y: min(max(point.y, radius + 72), max(radius + 72, size.height - radius - 88))
        )
    }
}

struct BubbleField: View {
    var people: [Person]
    var onSelect: (Person) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var world = BubbleWorld()

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
                let _ = world.reconcile(people: people, in: proxy.size)
                let _ = world.step(now: timeline.date, in: proxy.size, animated: !reduceMotion)
                ZStack {
                    ForEach(world.bodies) { body in
                        Button {
                            onSelect(body.person)
                        } label: {
                            LanternView(person: body.person, diameter: body.radius * 2)
                        }
                        .buttonStyle(.plain)
                        .position(body.position)
                        .accessibilityLabel(accessibilityLabel(for: body.person))
                    }
                }
            }
        }
    }

    private func accessibilityLabel(for person: Person) -> String {
        "\(person.name), \(person.circle.title), closeness \(person.closeness)"
    }
}
