import CoreGraphics

/// Drawing on the grass with or without the broadcast camera (BR-2). Without one, each call is exactly the flat
/// board's Core Graphics call, so the editor and the flat export draw as before. With one, what would be stroked is
/// turned into its outline on the plane first, so lines thin as they go away, and the outline is projected and filled.
extension CGContext {
    /// Strokes the current path in `colour` with the context's line width, cap, join and dash.
    func strokePath(_ colour: CGColor, camera: BroadcastCamera?) {
        guard let camera else {
            setStrokeColor(colour)
            strokePath()
            return
        }
        replacePathWithStrokedPath()
        fillProjected(colour, camera)
    }

    /// Fills the current path in `colour` (non-zero winding).
    func fillPath(_ colour: CGColor, camera: BroadcastCamera?) {
        guard let camera else {
            setFillColor(colour)
            fillPath()
            return
        }
        fillProjected(colour, camera)
    }

    /// Clips to the current path.
    func clip(camera: BroadcastCamera?) {
        if let camera, let path, !isPathEmpty {
            beginPath()
            addPath(camera.project(path))
        }
        clip()
    }

    func fill(_ rect: CGRect, _ colour: CGColor, camera: BroadcastCamera?) {
        guard camera != nil else {
            setFillColor(colour)
            fill(rect)
            return
        }
        addRect(rect)
        fillPath(colour, camera: camera)
    }

    func stroke(_ rect: CGRect, _ colour: CGColor, camera: BroadcastCamera?) {
        guard camera != nil else {
            setStrokeColor(colour)
            stroke(rect)
            return
        }
        addRect(rect)
        strokePath(colour, camera: camera)
    }

    func fillEllipse(in rect: CGRect, _ colour: CGColor, camera: BroadcastCamera?) {
        guard camera != nil else {
            setFillColor(colour)
            fillEllipse(in: rect)
            return
        }
        addEllipse(in: rect)
        fillPath(colour, camera: camera)
    }

    func strokeEllipse(in rect: CGRect, _ colour: CGColor, camera: BroadcastCamera?) {
        guard camera != nil else {
            setStrokeColor(colour)
            strokeEllipse(in: rect)
            return
        }
        addEllipse(in: rect)
        strokePath(colour, camera: camera)
    }

    private func fillProjected(_ colour: CGColor, _ camera: BroadcastCamera) {
        guard !isPathEmpty, let path else { return }
        beginPath()
        addPath(camera.project(path))
        setFillColor(colour)
        fillPath()
    }
}
