import CoreGraphics

/// Règles du geste de swipe, isolées de la vue pour pouvoir être testées.
enum SwipeResolver {
    static let commitDistance: CGFloat = 130
    static let commitVelocity: CGFloat = 700
    static let deadZone: CGFloat = 20

    /// Direction validée à la fin du geste, ou `nil` si la carte doit revenir en place.
    static func resolve(translation: CGSize, velocity: CGSize) -> SwipeDirection? {
        let horizontalWins = abs(translation.width) > abs(translation.height)
        let distance = horizontalWins ? abs(translation.width) : abs(translation.height)
        let speed = horizontalWins ? abs(velocity.width) : abs(velocity.height)
        guard distance > commitDistance || speed > commitVelocity else { return nil }

        if horizontalWins { return translation.width > 0 ? .right : .left }
        return translation.height > 0 ? .down : .up
    }

    /// Direction « en cours » pendant le glissement (pour afficher le badge), sans seuil de validation.
    static func activeDirection(for offset: CGSize) -> SwipeDirection? {
        guard offset != .zero else { return nil }
        if abs(offset.width) > abs(offset.height) {
            return offset.width > deadZone ? .right : (offset.width < -deadZone ? .left : nil)
        }
        return offset.height < -deadZone ? .up : (offset.height > deadZone ? .down : nil)
    }

    /// 0 → 1 (et au-delà) : avancement vers le seuil de validation.
    static func progress(for offset: CGSize) -> Double {
        Double(max(abs(offset.width), abs(offset.height)) / commitDistance)
    }

    /// Position de sortie de l'écran de la carte une fois le geste validé.
    static func flyOutOffset(for direction: SwipeDirection, translation: CGSize) -> CGSize {
        CGSize(
            width: direction == .right ? 900 : (direction == .left ? -900 : translation.width * 3),
            height: direction == .up ? -900 : (direction == .down ? 900 : translation.height * 3)
        )
    }
}
