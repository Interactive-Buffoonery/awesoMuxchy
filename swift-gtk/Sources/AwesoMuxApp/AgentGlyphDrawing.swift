import AwesoMuxCore
import Cairo
import CGtk
import Foundation
import Gtk

enum AgentGlyphDrawing {
    static func make(kind: SidebarAgentKind, tileSize: Int) -> WidgetRef {
        if kind == .pi {
            let label = LabelRef(str: "π")
            label.add(cssClass: "aw-agent-glyph")
            label.add(cssClass: cssClass(kind))
            label.setSizeRequest(width: tileSize, height: tileSize)
            setAccessibleHidden(label, true)
            return WidgetRef(label)
        }

        let area = DrawingAreaRef()
        area.add(cssClass: "aw-agent-glyph")
        area.add(cssClass: cssClass(kind))
        area.setSizeRequest(width: tileSize, height: tileSize)
        area.set(canTarget: false)
        setAccessibleHidden(area, true)
        area.setDrawFunc { area, context, width, height in
            var color = GdkRGBA()
            gtk_widget_get_color(area.widget_ptr, &color)
            context.setSource(
                red: Double(color.red), green: Double(color.green),
                blue: Double(color.blue), alpha: Double(color.alpha)
            )
            draw(kind: kind, in: context, width: Double(width), height: Double(height))
        }
        return WidgetRef(area)
    }

    private static func cssClass(_ kind: SidebarAgentKind) -> String {
        "aw-agent-\(kind.rawValue.lowercased())"
    }

    private static func draw(kind: SidebarAgentKind, in context: Cairo.ContextRef, width: Double, height: Double) {
        let tile = min(width, height)
        let size = tile * (kind == .shell ? 0.52 : 0.55)
        let x = (width - size) / 2
        let y = (height - size) / 2
        func point(_ px: Double, _ py: Double) -> (Double, Double) {
            (x + size * px, y + size * py)
        }

        context.lineWidth = tile * 0.053
        context.lineCap = Cairo.LineCap.round
        context.lineJoin = Cairo.LineJoin.round

        switch kind {
        case .claude:
            let center = point(0.5, 0.5)
            context.lineWidth = size * 0.067
            for index in 0..<8 {
                let angle = Double(index) * .pi / 4 - .pi / 2
                context.moveTo(
                    center.0 + cos(angle) * size * 0.215,
                    center.1 + sin(angle) * size * 0.215
                )
                context.lineTo(
                    center.0 + cos(angle) * size * 0.445,
                    center.1 + sin(angle) * size * 0.445
                )
            }
            context.stroke()
            context.arc(xc: center.0, yc: center.1, radius: size * 0.135)
            context.fill()
        case .codex:
            var p = point(0.77, 0.18); context.moveTo(p.0, p.1)
            p = point(0.15, 0.50)
            var c1 = point(0.43, 0.10), c2 = point(0.15, 0.25)
            context.curveTo(x1: c1.0, y1: c1.1, x2: c2.0, y2: c2.1, x3: p.0, y3: p.1)
            p = point(0.64, 0.82); c1 = point(0.15, 0.76); c2 = point(0.39, 0.87)
            context.curveTo(x1: c1.0, y1: c1.1, x2: c2.0, y2: c2.1, x3: p.0, y3: p.1)
            p = point(0.83, 0.63); c1 = point(0.76, 0.79); c2 = point(0.82, 0.72)
            context.curveTo(x1: c1.0, y1: c1.1, x2: c2.0, y2: c2.1, x3: p.0, y3: p.1)
            p = point(0.54, 0.36); c1 = point(0.82, 0.48); c2 = point(0.70, 0.36)
            context.curveTo(x1: c1.0, y1: c1.1, x2: c2.0, y2: c2.1, x3: p.0, y3: p.1)
            p = point(0.34, 0.53); c1 = point(0.41, 0.36); c2 = point(0.34, 0.44)
            context.curveTo(x1: c1.0, y1: c1.1, x2: c2.0, y2: c2.1, x3: p.0, y3: p.1)
            p = point(0.53, 0.68); c1 = point(0.34, 0.62); c2 = point(0.43, 0.68)
            context.curveTo(x1: c1.0, y1: c1.1, x2: c2.0, y2: c2.1, x3: p.0, y3: p.1)
            p = point(0.69, 0.55); c1 = point(0.62, 0.68); c2 = point(0.68, 0.62)
            context.curveTo(x1: c1.0, y1: c1.1, x2: c2.0, y2: c2.1, x3: p.0, y3: p.1)
            p = point(0.72, 0.51); c1 = point(0.70, 0.52); c2 = point(0.71, 0.51)
            context.curveTo(x1: c1.0, y1: c1.1, x2: c2.0, y2: c2.1, x3: p.0, y3: p.1)
            context.stroke()
        case .openCode:
            var p = point(0.33, 0.24); context.moveTo(p.0, p.1)
            p = point(0.20, 0.24); context.lineTo(p.0, p.1)
            p = point(0.20, 0.76); context.lineTo(p.0, p.1)
            p = point(0.33, 0.76); context.lineTo(p.0, p.1)
            p = point(0.67, 0.24); context.moveTo(p.0, p.1)
            p = point(0.80, 0.24); context.lineTo(p.0, p.1)
            p = point(0.80, 0.76); context.lineTo(p.0, p.1)
            p = point(0.67, 0.76); context.lineTo(p.0, p.1)
            context.stroke()
        case .grok:
            let center = point(0.5, 0.5)
            let radius = size * 0.30
            let offset = radius * 0.72
            for index in 0..<3 {
                let angle = Double(index) * 2 * .pi / 3 - .pi / 2
                context.newSubPath()
                context.arc(
                    xc: center.0 + cos(angle) * offset,
                    yc: center.1 + sin(angle) * offset,
                    radius: radius
                )
            }
            context.stroke()
        case .shell:
            var p = point(0.14, 0.30); context.moveTo(p.0, p.1)
            p = point(0.42, 0.50); context.lineTo(p.0, p.1)
            p = point(0.14, 0.70); context.lineTo(p.0, p.1)
            p = point(0.52, 0.70); context.moveTo(p.0, p.1)
            p = point(0.88, 0.70); context.lineTo(p.0, p.1)
            context.stroke()
        case .pi:
            break
        }
    }
}
