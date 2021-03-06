package quanto.gui;

import edu.uci.ics.jung.contrib.algorithms.layout.AKDotLayout;
import java.awt.Dimension;
import java.awt.Rectangle;
import java.awt.geom.Point2D;
import java.awt.geom.Rectangle2D;
import quanto.core.data.CoreGraph;
import quanto.core.data.Edge;
import quanto.core.data.Vertex;

public class JavaQuantoDotLayout
		extends AKDotLayout<Vertex, Edge> {

	private static final double VERTEX_PADDING = 20;
	private static final double EMPTY_BOX_SIZE = 40;
	private Rectangle boundingRect = new Rectangle(0, 0, 0, 0);

	public JavaQuantoDotLayout(CoreGraph graph, Dimension size) {
		super(graph);
	}

	public JavaQuantoDotLayout(CoreGraph graph) {
		this(graph, new Dimension(800, 600));
	}

	@Override
	public void initialize() {
		super.initialize();
		recalculateSize();
	}

	@Override
	public Dimension getSize() {
		return boundingRect.getSize();
	}

	@Override
	public void setLocation(Vertex picked, Point2D p) {
		if (p.getX() < 20) {
			p.setLocation(20, p.getY());
		}
		if (p.getY() < 20) {
			p.setLocation(p.getX(), 20);
		}
		super.setLocation(picked, p);
		boundingRect.add(new Rectangle2D.Double(
				p.getX() - VERTEX_PADDING,
				p.getY() - VERTEX_PADDING,
				2 * VERTEX_PADDING,
				2 * VERTEX_PADDING));
	}

	@Override
	public void setLocation(Vertex picked, double x, double y) {
		if (x < 20) {
			x = 20;
		}
		if (y < 20) {
			y = 20;
		}
		super.setLocation(picked, x, y);
		boundingRect.add(new Rectangle2D.Double(
				x - VERTEX_PADDING,
				y - VERTEX_PADDING,
				2 * VERTEX_PADDING,
				2 * VERTEX_PADDING));
	}

	public void recalculateSize() {
		double left = Double.MAX_VALUE;
		double top = Double.MAX_VALUE;
		double right = 0;
		double bottom = 0;
		for (Vertex v : getGraph().getVertices()) {
			Point2D point = transform(v);
			left = Math.min(left, point.getX());
			top = Math.min(top, point.getY());
			right = Math.max(right, point.getX());
			bottom = Math.max(bottom, point.getY());
		}
		left -= VERTEX_PADDING;
		top -= VERTEX_PADDING;
		right += VERTEX_PADDING;
		bottom += VERTEX_PADDING;
		if (left < right && top < bottom) {
			// get the same padding right and bottom as left and top
			boundingRect.setRect(
					0,
					0,
					right + left,
					bottom + top);
		} else {
			boundingRect.setRect(0, 0, EMPTY_BOX_SIZE, EMPTY_BOX_SIZE);
		}
	}
}
