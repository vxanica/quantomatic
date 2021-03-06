package quanto.gui;

import edu.uci.ics.jung.algorithms.layout.Layout;
import edu.uci.ics.jung.visualization.RenderContext;
import quanto.core.data.BangBox;
import quanto.core.data.Vertex;
import quanto.core.data.Edge;
import quanto.core.data.CoreGraph;
import quanto.core.data.VertexType;

import com.itextpdf.text.DocumentException;
import java.awt.*;
import java.awt.datatransfer.Clipboard;
import java.awt.datatransfer.StringSelection;
import java.awt.event.*;
import java.awt.geom.Ellipse2D;
import java.awt.geom.Point2D;
import java.awt.geom.Rectangle2D;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.lang.reflect.InvocationTargetException;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.SortedSet;
import java.util.TreeSet;

import javax.swing.*;
import javax.swing.event.ChangeEvent;
import javax.swing.event.ChangeListener;

import org.apache.commons.collections15.Transformer;

import quanto.core.CoreException;
import edu.uci.ics.jung.algorithms.layout.util.Relaxer;
import edu.uci.ics.jung.algorithms.layout.SmoothLayoutDecorator;
import edu.uci.ics.jung.contrib.visualization.control.AddEdgeGraphMousePlugin;
import edu.uci.ics.jung.contrib.visualization.control.ViewScrollingGraphMousePlugin;
import edu.uci.ics.jung.contrib.visualization.ViewZoomScrollPane;
import edu.uci.ics.jung.contrib.visualization.control.ConstrainedPickingBangBoxGraphMousePlugin;
import edu.uci.ics.jung.contrib.visualization.renderers.BangBoxLabelRenderer;
import edu.uci.ics.jung.visualization.Layer;
import edu.uci.ics.jung.visualization.VisualizationServer;
import edu.uci.ics.jung.visualization.control.*;
import edu.uci.ics.jung.contrib.visualization.ShapeBangBoxPickSupport;
import edu.uci.ics.jung.visualization.renderers.VertexLabelRenderer;
import edu.uci.ics.jung.visualization.transform.shape.GraphicsDecorator;
import java.awt.geom.AffineTransform;
import java.io.OutputStream;
import java.util.HashSet;
import java.util.logging.Level;
import java.util.logging.Logger;

import java.util.prefs.Preferences;
import javax.swing.filechooser.FileFilter;
import javax.swing.filechooser.FileNameExtensionFilter;
import quanto.core.data.AttachedRewrite;
import quanto.core.Core;
import quanto.core.protocol.userdata.CopyOfGraphUserDataSerializer;
import quanto.core.protocol.userdata.PositionGraphUserDataSerializer;
import quanto.gui.graphhelpers.ConstrainedMutableAffineTransformer;
import quanto.gui.graphhelpers.Labeler;
import quanto.gui.graphhelpers.QVertexRenderer;

public class InteractiveGraphView
		extends InteractiveView
		implements AddEdgeGraphMousePlugin.Adder<Vertex>,
		KeyListener {

	private static final long serialVersionUID = 7196565776978339937L;
	private static final Logger logger = Logger.getLogger("quanto.gui.InteractiveGraphView");
	private static Preferences prefsNode;
	
	public Map<String, ActionListener> actionMap = new HashMap<String, ActionListener>();
	private GraphVisualizationViewer viewer;
	private Core core;
	private RWMouse graphMouse;
	private volatile Job rewriter = null;
	private List<AttachedRewrite> rewriteCache = null;
	private boolean saveEnabled = true;
	private boolean saveAsEnabled = true;
	private boolean directedEdges = false;
	private SmoothLayoutDecorator<Vertex, Edge> smoothLayout;
	private Map<String, Point2D> verticesCache;
	private QuantoForceLayout forceLayout;
	private QuantoDotLayout initLayout;

	private JFileChooser graphSaveFileChooser;
	private JFileChooser pdfSaveFileChooser;

	public boolean viewHasParent() {
		return this.getParent() != null;
	}

	public static void setPreferencesNode(Preferences prefsNode) {
		InteractiveGraphView.prefsNode = prefsNode;
	}

	public static Preferences getPreferencesNode() {
		return prefsNode;
	}

	private class QVertexLabeler implements VertexLabelRenderer {

		Map<Vertex, Labeler> components;
		JLabel dummyLabel = new JLabel();
		JLabel realLabel = new JLabel();

		public QVertexLabeler() {
			components = new HashMap<Vertex, Labeler>();
			realLabel.setOpaque(true);
			realLabel.setBackground(Color.white);
		}

		public <T> Component getVertexLabelRendererComponent(JComponent vv,
				Object value, Font font, boolean isSelected, T vertex) {
			if (vertex instanceof Vertex) {
				final Vertex qVertex = (Vertex) vertex;
				if (!qVertex.isBoundaryVertex() && !qVertex.getVertexType().hasData()) {
					return dummyLabel;
				}

				Point2D screen = viewer.getRenderContext().
						getMultiLayerTransformer().transform(
						viewer.getGraphLayout().transform(qVertex));

				Labeler labeler;
				if (qVertex.isBoundaryVertex()) {
					String label = qVertex.getCoreName();
					labeler = components.get(qVertex);
					if (labeler == null) {
						labeler = new Labeler(label);
						components.put(qVertex, labeler);
						viewer.add(labeler);
						Color colour = new Color(0, 0, 0, 0);
						labeler.setColor(colour);
						labeler.addChangeListener(new ChangeListener() {

							public void stateChanged(ChangeEvent e) {
								Labeler lab = (Labeler) e.getSource();
								if (qVertex != null) {
									try {
										String newN = lab.getText();
										String oldN = qVertex.getCoreName();
										String displacedName = core.renameVertex(getGraph(), qVertex, newN);
										if (verticesCache != null) {
											if (displacedName != null) {
												Point2D oldP = verticesCache.get(newN);
												verticesCache.put(displacedName, oldP);
												verticesCache.remove(newN);
											}
											Point2D oldP = verticesCache.get(oldN);
											verticesCache.put(newN, oldP);
											verticesCache.remove(oldN);
										}
									} catch (CoreException err) {
										errorDialog(err.getMessage());
									}
								}
							}
						});
					} else {
						labeler.setText(label);
					}
				} else {
					// lazily create the labeler
					labeler = components.get(qVertex);
					if (labeler == null) {
						labeler = new Labeler(qVertex.getData());
						components.put(qVertex, labeler);
						viewer.add(labeler);
						Color colour = qVertex.getVertexType().getVisualizationData().getLabelColour();
						if (colour != null) {
							labeler.setColor(colour);
						}
						labeler.addChangeListener(new ChangeListener() {

							public void stateChanged(ChangeEvent e) {
								Labeler lab = (Labeler) e.getSource();
								if (qVertex != null) {
									try {
										core.setVertexAngle(getGraph(), qVertex, lab.getText());
									} catch (CoreException err) {
										coreErrorMessage("The label could not be updated", err);
									}
								}
							}
						});
					} else {
						labeler.update();
					}
				}

				Rectangle rect = new Rectangle(labeler.getPreferredSize());
				Point loc = new Point((int) (screen.getX() - rect.getCenterX()),
						(int) screen.getY() + 10);
				rect.setLocation(loc);

				if (!labeler.getBounds().equals(rect)) {
					labeler.setBounds(rect);
				}

				return dummyLabel;
			} else if (value != null) {
				realLabel.setText(value.toString());
				return realLabel;
			} else {
				return dummyLabel;
			}
		}

		/**
		 * Removes orphaned labels.
		 */
		public void cleanup() {
			final Map<Vertex, Labeler> oldComponents = components;
			components = new HashMap<Vertex, Labeler>();
			for (Labeler l : oldComponents.values()) {
				viewer.remove(l);
			}
		}
	}

	private class QBangBoxLabeler implements BangBoxLabelRenderer {

		Map<BangBox, Labeler> components;
		JLabel dummyLabel = new JLabel();
		JLabel realLabel = new JLabel();

		public QBangBoxLabeler() {
			components = new HashMap<BangBox, Labeler>();
			realLabel.setOpaque(true);
			realLabel.setBackground(Color.white);
		}

		public <T> Component getBangBoxLabelRendererComponent(JComponent vv,
				Object value, Font font, boolean isSelected, T bb) {
			if (bb instanceof BangBox) {
				final BangBox qBb = (BangBox) bb;

				//FIXME: This method is called a lot, it would probably be nicer
				//to store a map: BB -> Shape, so we compute the position of the
				//label directly from the shape of the BB and avoid all that min/max
				//thing.
				if (!getGraph().containsBangBox(qBb)) {
					return dummyLabel;
				}
				Collection<Vertex> bangedV = getGraph().getBoxedVertices(qBb);
				if (bangedV.isEmpty()) {
					return dummyLabel;
				}
				Point2D screen = new Point2D.Double(0, 0);
				SortedSet<Double> Xs = new TreeSet<Double>();
				SortedSet<Double> Ys = new TreeSet<Double>();

				for (Vertex v : bangedV) {
					Point2D p = viewer.getRenderContext().
							getMultiLayerTransformer().transform(
							viewer.getGraphLayout().transform(v));
					Xs.add(p.getX());
					Ys.add(p.getY());
				}
				screen.setLocation((Xs.last() - Xs.first()) / 2 + Xs.first(), Ys.first());
				String label = qBb.getCoreName();
				Labeler labeler = components.get(qBb);
				if (labeler == null) {
					labeler = new Labeler(label);
					components.put(qBb, labeler);
					viewer.add(labeler);
					Color colour = new Color(0, 0, 0, 0);
					labeler.setColor(colour);
					labeler.addChangeListener(new ChangeListener() {

						public void stateChanged(ChangeEvent e) {
							Labeler lab = (Labeler) e.getSource();
							if (qBb != null) {
								try {
									String newN = lab.getText();
									String oldN = qBb.getCoreName();
									core.renameBangBox(getGraph(), oldN, newN);
									qBb.updateCoreName(newN);
								} catch (CoreException err) {
									errorDialog(err.getMessage());
								}
							}
						}
					});
				}

				labeler.setText(label);

				Rectangle rect = new Rectangle(labeler.getPreferredSize());
				Point loc = new Point((int) (screen.getX() - rect.getCenterX()),
						(int) screen.getY() - 30);
				rect.setLocation(loc);

				if (!labeler.getBounds().equals(rect)) {
					labeler.setBounds(rect);
				}

				return dummyLabel;
			} else if (value != null) {
				realLabel.setText(value.toString());
				return realLabel;
			} else {
				return dummyLabel;
			}
		}

		/**
		 * Removes orphaned labels.
		 */
		public void cleanup() {
			final Map<BangBox, Labeler> oldComponents = components;
			components = new HashMap<BangBox, Labeler>();
			for (Labeler l : oldComponents.values()) {
				viewer.remove(l);
			}
		}
	}

	/**
	 * A graph mouse for doing most interactive graph operations.
	 *
	 */
	private class RWMouse extends PluggableGraphMouse {

		private GraphMousePlugin pickingMouse, edgeMouse;
		private boolean pickingMouseActive, edgeMouseActive;

		public RWMouse() {
			add(new ScalingGraphMousePlugin(new ViewScalingControl(), QuantoApp.COMMAND_MASK));
			add(new ViewTranslatingGraphMousePlugin(InputEvent.BUTTON1_MASK | QuantoApp.COMMAND_MASK));
			ViewScrollingGraphMousePlugin scrollerPlugin = new ViewScrollingGraphMousePlugin();
			scrollerPlugin.setShift(10.0);
			add(scrollerPlugin);
			add(new AddEdgeGraphMousePlugin<Vertex, Edge>(
					viewer,
					InteractiveGraphView.this,
					InputEvent.BUTTON1_MASK | InputEvent.ALT_MASK));
			pickingMouse = new ConstrainedPickingBangBoxGraphMousePlugin<Vertex, Edge, BangBox>(20.0, 20.0) {
				// don't change the cursor

				@Override
				public void mouseEntered(MouseEvent e) {
				}

				@Override
				public void mouseExited(MouseEvent e) {
				}

				@Override
				public void mouseReleased(MouseEvent e) {
					super.mouseReleased(e);
					setVerticesPositionData();
				}
			};
			edgeMouse = new AddEdgeGraphMousePlugin<Vertex, Edge>(
					viewer,
					InteractiveGraphView.this,
					InputEvent.BUTTON1_MASK);
			setPickingMouse();
		}

		public void clearMouse() {
			edgeMouseActive = false;
			remove(edgeMouse);
			pickingMouseActive = false;
			remove(pickingMouse);
		}

		final public void setPickingMouse() {
			clearMouse();
			pickingMouseActive = true;
			add(pickingMouse);
			InteractiveGraphView.this.repaint();
			if (isAttached()) {
				getViewPort().setCommandStateSelected(CommandManager.Command.SelectMode, true);
			}
		}

		public void setEdgeMouse() {
			clearMouse();
			edgeMouseActive = true;
			add(edgeMouse);
			InteractiveGraphView.this.repaint();
			if (isAttached()) {
				if (directedEdges) {
					getViewPort().setCommandStateSelected(CommandManager.Command.DirectedEdgeMode, true);
				} else {
					getViewPort().setCommandStateSelected(CommandManager.Command.UndirectedEdgeMode, true);
				}
			}
		}

		public boolean isPickingMouse() {
			return pickingMouseActive;
		}

		public boolean isEdgeMouse() {
			return edgeMouseActive;
		}
	}

	public InteractiveGraphView(Core core, CoreGraph g) throws CoreException {
		this(core, g, new Dimension(800, 600));
	}

	public InteractiveGraphView(Core core, CoreGraph g, Dimension size) throws CoreException {
		super(g.getCoreName());
		setPreferredSize(size);
		initLayout = new QuantoDotLayout(g);
		initLayout.initialize();
		forceLayout = new QuantoForceLayout(g, initLayout, 20.0);
		smoothLayout = new SmoothLayoutDecorator<Vertex, Edge>(forceLayout);
		viewer = new GraphVisualizationViewer(smoothLayout);

		/* This is probably not the place to do it:
		 * get vertices user data from graph, and set
		 * position.*/
		Map<String, Vertex> vmap = g.getVertexMap();
		for (String key : vmap.keySet()) {
			PositionGraphUserDataSerializer pds = new PositionGraphUserDataSerializer(core.getTalker());
			Point2D p = (Point2D) pds.getVertexUserData(g, key);
			if (p != null) {
				viewer.getGraphLayout().setLocation(vmap.get(key), p);
				viewer.getGraphLayout().lock(vmap.get(key), true);
			}
		}
		setMainComponent(new ViewZoomScrollPane(viewer));

		this.core = core;
		Relaxer r = viewer.getModel().getRelaxer();
		if (r != null) {
			r.setSleepTime(10);
		}

		graphMouse = new RWMouse();
		viewer.setGraphMouse(graphMouse);

		viewer.getRenderContext().getMultiLayerTransformer().setTransformer(Layer.VIEW, new ConstrainedMutableAffineTransformer());
		viewer.getRenderContext().getMultiLayerTransformer().setTransformer(Layer.LAYOUT, new ConstrainedMutableAffineTransformer());

		viewer.addPreRenderPaintable(new VisualizationServer.Paintable() {

			public void paint(Graphics g) {
				Color old = g.getColor();
				g.setColor(Color.red);
				if ((graphMouse.isEdgeMouse()) && (directedEdges)) {
					g.drawString("DIRECTED EDGE MODE", 5, 15);
				} else if (graphMouse.isEdgeMouse()) {
					g.drawString("UNDIRECTED EDGE MODE", 5, 15);
				}
				g.setColor(old);
			}

			public boolean useTransform() {
				return false;
			}
		});

		viewer.addMouseListener(new MouseAdapter() {

			@Override
			public void mousePressed(MouseEvent e) {
				InteractiveGraphView.this.grabFocus();
				super.mousePressed(e);
			}
		});

		addKeyListener(this);
		viewer.addKeyListener(this);

		viewer.getRenderContext().setVertexDrawPaintTransformer(
				new Transformer<Vertex, Paint>() {

					public Paint transform(Vertex v) {
						if (isVertexLocked(v)) {
							return Color.gray;
						} else {
							return Color.black;
						}
					}
				});
		viewer.getRenderer().setVertexRenderer(new QVertexRenderer() {

			@Override
			public void paintVertex(RenderContext<Vertex, Edge> rc, Layout<Vertex, Edge> layout, Vertex v) {
				if (rc.getPickedVertexState().isPicked(v)) {
					Rectangle bounds = rc.getVertexShapeTransformer().transform(v).getBounds();
					Point2D p = layout.transform(v);
					p = rc.getMultiLayerTransformer().transform(Layer.LAYOUT, p);
					float x = (float) p.getX();
					float y = (float) p.getY();
					// create a transform that translates to the location of
					// the vertex to be rendered
					AffineTransform xform = AffineTransform.getTranslateInstance(x, y);
					// transform the vertex shape with xtransform
					bounds = xform.createTransformedShape(bounds).getBounds();
					bounds.translate(-1, -1);

					GraphicsDecorator g = rc.getGraphicsContext();
					bounds.grow(3, 3);
					g.setColor(new Color(200, 200, 255));
					g.fillRoundRect(bounds.x, bounds.y, bounds.width, bounds.height, 4, 4);
					g.setColor(Color.BLUE);
					g.drawRoundRect(bounds.x, bounds.y, bounds.width, bounds.height, 4, 4);
				}
				super.paintVertex(rc, layout, v);
			}
		});

		viewer.getRenderContext().setVertexLabelRenderer(new QVertexLabeler());
		viewer.getRenderContext().setBangBoxLabelRenderer(new QBangBoxLabeler());
		// increase the picksize
		viewer.setPickSupport(new ShapeBangBoxPickSupport<Vertex, Edge, BangBox>(viewer, 4));
		viewer.setBoundingBoxEnabled(false);

		buildActionMap();

		g.addChangeListener(new ChangeListener() {

			public void stateChanged(ChangeEvent e) {
				removeOldLabels();
				if (saveEnabled && isAttached()) {
					getViewPort().setCommandEnabled(CommandManager.Command.Save,
							!getGraph().isSaved());
					firePropertyChange("saved", !getGraph().isSaved(), getGraph().isSaved());
				}
			}
		});
	}

	public boolean isVertexLocked(Vertex v) {
		return viewer.getGraphLayout().isLocked(v);
	}

	public void lockVertices(Collection<Vertex> verts) {
		for (Vertex v : verts) {
			viewer.getGraphLayout().lock(v, true);
		}
	}

	public void unlockVertices(Collection<Vertex> verts) {
		for (Vertex v : verts) {
			viewer.getGraphLayout().lock(v, false);
		}
	}

	public boolean isSaveEnabled() {
		return saveEnabled;
	}

	public void setSaveEnabled(boolean saveEnabled) {
		if (this.saveEnabled != saveEnabled) {
			this.saveEnabled = saveEnabled;
			if (isAttached()) {
				getViewPort().setCommandEnabled(
						CommandManager.Command.Save,
						saveEnabled && !isSaved());
			}
			if (saveEnabled) {
				actionMap.put(CommandManager.Command.Save.toString(), new ActionListener() {

					public void actionPerformed(ActionEvent e) {
						saveGraph();
					}
				});
			} else {
				actionMap.remove(CommandManager.Command.Save.toString());
			}
		}
	}

	public boolean isSaveAsEnabled() {
		return saveAsEnabled;
	}

	public void setSaveAsEnabled(boolean saveAsEnabled) {
		if (this.saveAsEnabled != saveAsEnabled) {
			this.saveAsEnabled = saveAsEnabled;
			if (isAttached()) {
				getViewPort().setCommandEnabled(
						CommandManager.Command.SaveAs,
						saveAsEnabled);
			}
			if (saveAsEnabled) {
				actionMap.put(CommandManager.Command.SaveAs.toString(), new ActionListener() {

					public void actionPerformed(ActionEvent e) {
						saveGraphAs();
					}
				});
			} else {
				actionMap.remove(CommandManager.Command.SaveAs.toString());
			}
		}
	}

	public GraphVisualizationViewer getVisualization() {
		return viewer;
	}

	public void addChangeListener(ChangeListener listener) {
		viewer.addChangeListener(listener);
	}

	public CoreGraph getGraph() {
		return viewer.getGraph();
	}

	/**
	 * Compute a bounding box and scale such that the largest
	 * dimension fits within the view port.
	 */
	public void zoomToFit() {
		viewer.zoomToFit(getSize());
	}

	public static String titleOfGraph(String name) {
		return "graph (" + name + ")";
	}

	public void addEdge(Vertex s, Vertex t) {
		try {
			core.addEdge(getGraph(), directedEdges, s, t);
		} catch (CoreException e) {
			coreErrorDialog("Could not add a directed edge", e);
		}
	}

	public void addBoundaryVertex() {
		try {
			core.addBoundaryVertex(getGraph());
			setVerticesPositionData();
		} catch (CoreException e) {
			coreErrorDialog("Could not add a boundary vertex", e);
		}
	}

	public void addVertex(String type) {
		try {
			core.addVertex(getGraph(), type);
			setVerticesPositionData();
		} catch (CoreException e) {
			coreErrorDialog("Could not add a vertex", e);
		}
	}

	public void showRewrites() {
		try {
			Set<Vertex> picked = viewer.getPickedVertexState().getPicked();
			if (picked.isEmpty()) {
				core.attachRewrites(getGraph(), getGraph().getVertices());
			} else {
				core.attachRewrites(getGraph(), picked);
			}
			JFrame rewrites = new RewriteViewer(InteractiveGraphView.this);
			rewrites.setVisible(true);
		} catch (CoreException e) {
			coreErrorDialog("Could not obtain the rewrites", e);
		}
	}

	public void removeOldLabels() {
		((QVertexLabeler) viewer.getRenderContext().getVertexLabelRenderer()).cleanup();
		((QBangBoxLabeler) viewer.getRenderContext().getBangBoxLabelRenderer()).cleanup();
	}

	@Override
	public void cleanUp() {
		removeOldLabels();
		((QVertexLabeler) viewer.getRenderContext().getVertexLabelRenderer()).cleanup();
		((QBangBoxLabeler) viewer.getRenderContext().getBangBoxLabelRenderer()).cleanup();
		if (saveEnabled && isAttached()) {
			getViewPort().setCommandEnabled(CommandManager.Command.Save,
					!getGraph().isSaved());
		}
	}

	public void cacheVertexPositions() {
		verticesCache = new HashMap<String, Point2D>();
		for (Vertex v : getGraph().getVertices()) {
			int X = (int) smoothLayout.getDelegate().transform(v).getX();
			int Y = (int) smoothLayout.getDelegate().transform(v).getY();
			Point2D p = new Point2D.Double(X, Y);
			verticesCache.put(v.getCoreName(), p);
		}
	}

	public void setVertexPositionData(Vertex v) {
		try {
			core.startUndoGroup(getGraph());
			PositionGraphUserDataSerializer pds = new PositionGraphUserDataSerializer(core.getTalker());
			int X = (int) smoothLayout.getDelegate().transform(v).getX();
			int Y = (int) smoothLayout.getDelegate().transform(v).getY();
			Point2D new_p = new Point2D.Double(X, Y);
			pds.setVertexUserData(getGraph(), v.getCoreName(), new_p);
			core.endUndoGroup(getGraph());
		} catch (CoreException e) {
			errorDialog(e.getMessage());
		}
	}

	public void setVerticesPositionData() {
		CoreGraph graph = getGraph();
		PositionGraphUserDataSerializer pds = new PositionGraphUserDataSerializer(core.getTalker());
		try {
			//New vertices are added but not pushed on the undo stack 
			core.startUndoGroup(graph);
			for (Vertex v : graph.getVertices()) {
				int X = (int) smoothLayout.getDelegate().transform(v).getX();
				int Y = (int) smoothLayout.getDelegate().transform(v).getY();
				Point2D old_p = pds.getVertexUserData(graph, v.getCoreName());
				Point2D new_p = new Point2D.Double(X, Y);
				if (old_p == null) {
					pds.setVertexUserData(graph, v.getCoreName(), new_p);
				}
			}
			core.endUndoGroup(graph);

			ArrayList<Vertex> vertices = new ArrayList<Vertex>();
			for (Vertex v : graph.getVertices()) {
				int X = (int) smoothLayout.getDelegate().transform(v).getX();
				int Y = (int) smoothLayout.getDelegate().transform(v).getY();
				Point2D old_p = (Point2D) pds.getVertexUserData(graph, v.getCoreName());
				Point2D new_p = new Point2D.Double(X, Y);
				if (old_p.distance(new_p) > 1.5) {
					vertices.add(v);
				}
			}
			if (vertices.size() > 0) {
				//The first one creates an undo point
				Vertex v = vertices.get(0);
				int X = (int) smoothLayout.getDelegate().transform(v).getX();
				int Y = (int) smoothLayout.getDelegate().transform(v).getY();
				Point2D new_p = new Point2D.Double(X, Y);
				pds.setVertexUserData(graph, v.getCoreName(), new_p);
				vertices.remove(v);
			}
			if (vertices.size() <= 0) {
				return;
			}
			//The others do not
			core.startUndoGroup(graph);
			for (Vertex v : vertices) {
				int X = (int) smoothLayout.getDelegate().transform(v).getX();
				int Y = (int) smoothLayout.getDelegate().transform(v).getY();
				Point2D new_p = new Point2D.Double(X, Y);
				pds.setVertexUserData(graph, v.getCoreName(), new_p);
			}
			core.endUndoGroup(graph);
		} catch (CoreException e) {
			errorDialog(e.getMessage());
		}
	}

	public void updateGraph(Rectangle2D rewriteRect) throws CoreException {
		core.updateGraph(getGraph());
		relayoutGraph(rewriteRect);
	}

	public void relayoutGraph(Rectangle2D rewriteRect) throws CoreException {
		int count = 0;
		for (Vertex v : getGraph().getVertices()) {
			if (verticesCache.get(v.getCoreName()) != null) {
				PositionGraphUserDataSerializer pds = new PositionGraphUserDataSerializer(core.getTalker());
				Point2D p = (Point2D) pds.getVertexUserData(getGraph(), v.getCoreName());
				if (p == null) p = verticesCache.get(v.getCoreName());
				
				viewer.getGraphLayout().setLocation(v, p);
				viewer.getGraphLayout().lock(v, true);
			} else {
				if (rewriteRect != null) {
					PositionGraphUserDataSerializer pds = new PositionGraphUserDataSerializer(core.getTalker());
					Point2D p = (Point2D) pds.getVertexUserData(getGraph(), v.getCoreName());
					if (p != null) {
						viewer.getGraphLayout().setLocation(v, p);
						viewer.getGraphLayout().lock(v, true);
					} else {
						if (rewriteRect.getCenterX() <= 10 || rewriteRect.getCenterX() <= 10)
							viewer.getGraphLayout().setLocation(v, new Point2D.Double(20 * (1 + count), 20 * (1 + count)));
						else
							viewer.shift(rewriteRect, v, new Point2D.Double(20 * (1 + count), 20 * (1 + count)));
						
						setVertexPositionData(v);
						count++;
					}
				} else {
					// ... log here
				}
			}
		}
		forceLayout.startModify();
		viewer.modifyLayout();
		forceLayout.endModify();
		removeOldLabels();
		viewer.update();
		//locking and unlocking used internally to notify the layout which vertices have user data
		unlockVertices(getGraph().getVertices());
	}

	public void outputToTextView(String text) {
		TextView tview = new TextView(getTitle() + "-output", text);
		getViewManager().addView(tview);

		if (isAttached()) {
			getViewPort().openView(tview);
		}
	}
	private SubgraphHighlighter highlighter = null;

	public void clearHighlight() {
		if (highlighter != null) {
			viewer.removePostRenderPaintable(highlighter);
		}
		highlighter = null;
		viewer.repaint();
	}

	public void highlightSubgraph(Collection<Vertex> vs) {
		clearHighlight();
		highlighter = new SubgraphHighlighter(vs);
		viewer.addPostRenderPaintable(highlighter);
		viewer.update();
	}

	public void highlightRewrite(AttachedRewrite rw) {
		highlightSubgraph(rw.getRemovedVertices());
	}

	public void startRewriting() {
		abortRewriting();
		rewriter = new RewriterJob();
		rewriter.addJobListener(new JobListener() {

			public void jobEnded(JobEndEvent event) {
				if (rewriter != null) {
					rewriter = null;
				}
				if (isAttached()) {
					setupNormaliseAction(getViewPort());
				}
			}
		});
		rewriter.start();
		showJobIndicator("Rewriting...", rewriter);
		if (isAttached()) {
			setupNormaliseAction(getViewPort());
		}
	}

	public void abortRewriting() {
		if (rewriter != null) {
			rewriter.abortJob();
			rewriter = null;
		}
	}

	private void setupNormaliseAction(ViewPort vp) {
		if (rewriter == null) {
			vp.setCommandEnabled(CommandManager.Command.Normalise, true);
		} else {
			vp.setCommandEnabled(CommandManager.Command.Normalise, false);
		}
	}

	private class RewriterJob extends Job {

		private boolean highlight = false;

		private boolean attachNextRewrite() {
			try {
				return core.attachOneRewrite(
						getGraph(),
						getGraph().getVertices());
			} catch (CoreException e) {
				coreErrorDialog("Could not attach the next rewrite", e);
				return false;
			}
		}

		private void invokeHighlightRewriteAndWait(AttachedRewrite rw)
				throws InterruptedException {
			highlight = true;
			final AttachedRewrite fRw = rw;
			invokeAndWait(new Runnable() {

				public void run() {
					highlightRewrite(fRw);
				}
			});
		}

		private void invokeApplyRewriteAndWait(int index)
				throws InterruptedException {
			highlight = false;
			final int fIndex = index;
			invokeAndWait(new Runnable() {

				public void run() {
					clearHighlight();
					applyRewrite(fIndex);
				}
			});
		}

		private void invokeClearHighlightLater() {
			highlight = false;
			SwingUtilities.invokeLater(new Runnable() {

				public void run() {
					clearHighlight();
				}
			});
		}

		private void invokeInfoDialogAndWait(String message)
				throws InterruptedException {
			final String fMessage = message;
			invokeAndWait(new Runnable() {

				public void run() {
					infoDialog(fMessage);
				}
			});
		}

		private void invokeAndWait(Runnable runnable)
				throws InterruptedException {
			try {
				SwingUtilities.invokeAndWait(runnable);
			} catch (InvocationTargetException ex) {
				logger.log(Level.WARNING,
						"invoke and wait failed", ex);
			}
		}

		@Override
		public void run() {
			try {
				// FIXME: communicating with the core: is this
				//        really threadsafe?  Probably not.

				int count = 0;
				while (!Thread.interrupted() && attachNextRewrite()) {
					List<AttachedRewrite> rws = getRewrites();
					invokeHighlightRewriteAndWait(rws.get(0));
					sleep(1500);
					invokeApplyRewriteAndWait(0);
					++count;
				}

				fireJobFinished();
				invokeInfoDialogAndWait("Applied " + count + " rewrites");
			} catch (InterruptedException e) {
				if (highlight) {
					invokeClearHighlightLater();
				}
			}
		}
	}

	private class SubgraphHighlighter
			implements VisualizationServer.Paintable {

		Collection<Vertex> verts;

		public SubgraphHighlighter(Collection<Vertex> vs) {
			verts = vs;
		}

		public void paint(Graphics g) {
			Color oldColor = g.getColor();
			g.setColor(Color.blue);
			Graphics2D g2 = (Graphics2D) g.create();
			float opac = 0.3f + 0.2f * (float) Math.sin(
					System.currentTimeMillis() / 150.0);
			g2.setComposite(AlphaComposite.getInstance(AlphaComposite.SRC_OVER, opac));

			for (Vertex v : verts) {
				Point2D pt = viewer.getGraphLayout().transform(v);
				Ellipse2D ell = new Ellipse2D.Double(
						pt.getX() - 15, pt.getY() - 15, 30, 30);
				Shape draw = viewer.getRenderContext().getMultiLayerTransformer().transform(ell);
				((Graphics2D) g2).fill(draw);
			}

			g2.dispose();
			g.setColor(oldColor);
			repaint(10);
		}

		public boolean useTransform() {
			return false;
		}
	}

	/**
	 * Gets the attached rewrites as a list of Pair<QGraph>. Returns and empty
	 * list on console error.
	 * @return
	 */
	public List<AttachedRewrite> getRewrites() {
		try {
			rewriteCache = core.getAttachedRewrites(getGraph());
			return rewriteCache;
		} catch (CoreException e) {
			coreErrorDialog("Could not obtain the rewrites", e);
		}

		return new ArrayList<AttachedRewrite>();
	}

	public void applyRewrite(int index) {
		Rectangle2D rewriteRect = new Rectangle2D.Double();
		try {
			AttachedRewrite rw = rewriteCache.get(index);
			viewer.setCoreGraph(rw.getGraph());
			Collection<Vertex> removed = rw.getRemovedVertices();
			if (removed.size() > 0) {
				rewriteRect = viewer.getSubgraphBounds(removed);
				if (removed.size() == 1) {
					smoothLayout.setOrigin(rewriteRect.getCenterX(), rewriteRect.getCenterY());
				}
			}
			cacheVertexPositions();
			core.applyAttachedRewrite(getGraph(), index);
			relayoutGraph(rewriteRect);
			smoothLayout.setOrigin(0, 0);
		} catch (CoreException e) {
			coreErrorDialog("Could not apply the rewrite", e);
		}
	}

	public Core getCore() {
		return core;
	}

	@Override
	public void commandTriggered(String command) {
		ActionListener listener = actionMap.get(command);
		if (listener != null) {
			listener.actionPerformed(new ActionEvent(this, -1, command));
		} else {
			super.commandTriggered(command);
		}
	}

	public void saveGraphAs() {
		if (graphSaveFileChooser == null) {
			graphSaveFileChooser = new JFileChooser();
			graphSaveFileChooser.setDialogType(JFileChooser.SAVE_DIALOG);
			FileFilter filter = new FileNameExtensionFilter("Quanto graph",
					"graph", "qgr");
			graphSaveFileChooser.addChoosableFileFilter(filter);
			graphSaveFileChooser.setFileFilter(filter);
			if (prefsNode != null) {
				String path = prefsNode.get("lastGraphDir", null);
				if (path != null) {
					graphSaveFileChooser.setCurrentDirectory(new File(path));
				}
			}
		}
		String fileName = getGraph().getFileName();
		if (fileName != null && !fileName.isEmpty()) {
			graphSaveFileChooser.setSelectedFile(new File(fileName));
		}
		
		int retVal = graphSaveFileChooser.showDialog(this, "Save Graph");
		if (retVal == JFileChooser.APPROVE_OPTION) {
			File f = graphSaveFileChooser.getSelectedFile();
			if (f.exists()) {
				int overwriteAnswer = JOptionPane.showConfirmDialog(
						this,
						"Are you sure you want to overwrite \"" + f.getName() + "\"?",
						"Overwrite file?",
						JOptionPane.YES_NO_OPTION);
				if (overwriteAnswer != JOptionPane.YES_OPTION) {
					return;
				}
			}
			if (f.getParent() != null && prefsNode != null) {
				prefsNode.put("lastGraphDir", f.getParent());
			}
			try {
				core.saveGraph(getGraph(), f);
				core.renameGraph(getGraph(), f.getName());
				getGraph().setFileName(f.getAbsolutePath());
				getGraph().setSaved(true);
				firePropertyChange("saved", !getGraph().isSaved(), getGraph().isSaved());
				setTitle(f.getName());
			} catch (CoreException e) {
				coreErrorDialog("Could not save the graph", e);
			} catch (IOException e) {
				detailedErrorDialog("Save Graph", "Could not save the graph", e.getLocalizedMessage());
			}
		}
	}

	public void saveGraph() {
		if (getGraph().getFileName() != null) {
			try {
				core.saveGraph(getGraph(), new File(getGraph().getFileName()));
				getGraph().setSaved(true);
				firePropertyChange("saved", !getGraph().isSaved(), getGraph().isSaved());
			} catch (CoreException e) {
				coreErrorDialog("Could not save the graph", e);
			} catch (IOException e) {
				detailedErrorDialog("Save Graph", "Could not save the graph", e.getLocalizedMessage());
			}
		} else {
			saveGraphAs();
		}
	}
	
	public void exportToPdf() {
		try {
			if (pdfSaveFileChooser == null) {
				pdfSaveFileChooser = new JFileChooser();
				pdfSaveFileChooser.setDialogType(JFileChooser.SAVE_DIALOG);
				FileFilter filter = new FileNameExtensionFilter("PDF Document", "pdf");
				pdfSaveFileChooser.addChoosableFileFilter(filter);
				pdfSaveFileChooser.setFileFilter(filter);
				String fileName = getGraph().getFileName();
				if (fileName != null && !fileName.isEmpty()) {
					pdfSaveFileChooser.setCurrentDirectory(new File(fileName).getParentFile());
				} else if (prefsNode != null) {
					String path = prefsNode.get("lastPdfDir", null);
					if (path != null) {
						pdfSaveFileChooser.setCurrentDirectory(new File(path));
					}
				}
			}
			int retVal = graphSaveFileChooser.showDialog(this, "Export to PDF");
			if (retVal == JFileChooser.APPROVE_OPTION) {
				File f = graphSaveFileChooser.getSelectedFile();
				if (f.exists()) {
					int overwriteAnswer = JOptionPane.showConfirmDialog(
							this,
							"Are you sure you want to overwrite \"" + f.getName() + "\"?",
							"Overwrite file?",
							JOptionPane.YES_NO_OPTION);
					if (overwriteAnswer != JOptionPane.YES_OPTION) {
						return;
					}
				}
				if (f.getParent() != null && prefsNode != null) {
					prefsNode.put("lastPdfDir", f.getParent());
				}
				OutputStream file = new FileOutputStream(f);
				PdfGraphVisualizationServer server = new PdfGraphVisualizationServer(core.getActiveTheory(), getGraph());
				server.renderToPdf(file);
				file.close();
			}
		} catch (DocumentException ex) {
			detailedErrorMessage("Could not generate the PDF", ex);
		} catch (IOException ex) {
			detailedErrorMessage("Could not save the PDF", ex);
		}
	}
	
	public static String getLastGraphDirectory() {
		if (prefsNode != null) {
			return prefsNode.get("lastGraphDir", null);
		}
		return null;
	}
	
	/**
	 * Presents the user with an "Open Graph" dialog
	 * 
	 * The directory will be set to the last directory that was used for
	 * opening or saving a graph.
	 *
	 * @param parent
	 * @return 
	 */
	public static File chooseGraphFile(Component parent) {
		JFileChooser chooser = new JFileChooser();
		chooser.setDialogType(JFileChooser.OPEN_DIALOG);
		FileFilter filter = new FileNameExtensionFilter("Quanto graph",
				"graph", "qgr");
		chooser.addChoosableFileFilter(filter);
		chooser.setFileFilter(filter);
		String path = getLastGraphDirectory();
		if (path != null) {
			chooser.setCurrentDirectory(new File(path));
		}
		int retVal = chooser.showDialog(parent, "Open Graph");
		if (retVal == JFileChooser.APPROVE_OPTION) {
			File f = chooser.getSelectedFile();
			if (f.getParent() != null && prefsNode != null) {
				prefsNode.put("lastGraphDir", f.getParent());
			}
			return f;
		} else {
			return null;
		}
	}

	public static void registerKnownCommands(Core core, CommandManager commandManager) {
		/*
		 * Add commands dynamically and add registered vertex types
		 */
		for (VertexType vertexType : core.getActiveTheory().getVertexTypes()) {
			commandManager.registerCommand("add-" + vertexType.getTypeName() + "-vertex-command");
		}
	}

	private void buildActionMap() {
		actionMap.put(CommandManager.Command.Save.toString(), new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				saveGraph();
			}
		});
		actionMap.put(CommandManager.Command.SaveAs.toString(), new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				saveGraphAs();
			}
		});

		actionMap.put(CommandManager.Command.Undo.toString(), new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				try {
					cacheVertexPositions();
					Rectangle2D rect = viewer.getGraphBounds();
					core.undo(getGraph());
					relayoutGraph(rect);
				} catch (CoreException ex) {
					coreErrorDialog("Could not undo", ex);
				}
			}
		});
		actionMap.put(CommandManager.Command.Redo.toString(), new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				try {
					cacheVertexPositions();
					Rectangle2D rect = viewer.getGraphBounds();
					core.redo(getGraph());
					relayoutGraph(rect);
				} catch (CoreException ex) {
					coreErrorDialog("Could not redo", ex);
				}
			}
		});
		actionMap.put(CommandManager.Command.UndoRewrite.toString(), new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				try {
					cacheVertexPositions();
					Rectangle2D rect = viewer.getGraphBounds();
					core.undoRewrite(getGraph());
					relayoutGraph(rect);
				} catch (CoreException ex) {
					coreErrorDialog("Could not undo", ex);
				}
			}
		});
		actionMap.put(CommandManager.Command.RedoRewrite.toString(), new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				try {
					cacheVertexPositions();
					Rectangle2D rect = viewer.getGraphBounds();
					core.redoRewrite(getGraph());
					relayoutGraph(rect);
				} catch (CoreException ex) {
					coreErrorDialog("Could not redo", ex);
				}
			}
		});
		actionMap.put(CommandManager.Command.Cut.toString(), new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				try {
					Set<Vertex> picked = viewer.getPickedVertexState().getPicked();
					if (!picked.isEmpty()) {
						core.cutSubgraph(getGraph(), picked);
					}
				} catch (CoreException ex) {
					coreErrorDialog("Could not cut selection", ex);
				}
			}
		});
		actionMap.put(CommandManager.Command.Copy.toString(), new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				try {
					Set<Vertex> picked = viewer.getPickedVertexState().getPicked();
					if (!picked.isEmpty()) {
						core.copySubgraph(getGraph(), picked);
					}
				} catch (CoreException ex) {
					coreErrorDialog("Could not copy selection", ex);
				}
			}
		});
		actionMap.put(CommandManager.Command.Paste.toString(), new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				try {
					cacheVertexPositions();
					Rectangle2D rect = viewer.getGraphBounds();
					core.paste(getGraph());
					/* 
					 * FIXME: maybe, this is not the right place? 
					 * When we paste a graph we want to keep it's layout as well, so we get it's quanto-position uidata
					 * and translate everything so that it ends up at the right of the current graph.
					 * What we get is a graph, already merged and with fresh names. So in order to know which one 
					 * were copied we check the "copy_of" user_data which is set automatically by the core when a
					 * subgraph get copied, and delete it afterwards.
					 *  */
					CopyOfGraphUserDataSerializer cos = new CopyOfGraphUserDataSerializer(core.getTalker());
					PositionGraphUserDataSerializer pos = new PositionGraphUserDataSerializer(core.getTalker());

					core.startUndoGroup(getGraph());
					for (Vertex v : getGraph().getVertices()) {
						String copy_of_vertex = (String) cos.getVertexUserData(getGraph(), v.getCoreName());
						if ((copy_of_vertex != null) && (!copy_of_vertex.equals(""))) {
							//Then translate its quanto-gui:position
							Point2D position = (Point2D) pos.getVertexUserData(getGraph(), v.getCoreName());
							position.setLocation(position.getX() + rect.getCenterX() + 20, position.getY());
							pos.setVertexUserData(getGraph(), v.getCoreName(), position);
							cos.deleteVertexUserData(getGraph(), v.getCoreName());
						}
					}
					/* For now we do nothing with Edge and !-Boxes user data but still need to remove their "copy_of" UD */
					for (Edge edge : getGraph().getEdges()) {
						String copy_of = (String) cos.getEdgeUserData(getGraph(), edge.getCoreName());
						if ((copy_of != null) && (!copy_of.equals(""))) {
							cos.deleteEdgeUserData(getGraph(), edge.getCoreName());
						}
					}
					for (BangBox bb : getGraph().getBangBoxes()) {
						String copy_of = (String) cos.getBangBoxUserData(getGraph(), bb.getCoreName());
						if ((copy_of != null) && (!copy_of.equals(""))) {
							cos.deleteBangBoxUserData(getGraph(), bb.getCoreName());
						}
					}
					core.endUndoGroup(getGraph());
					updateGraph(rect);
				} catch (CoreException ex) {
					coreErrorDialog("Could not paste selection", ex);
				}
			}
		});
		actionMap.put(CommandManager.Command.SelectAll.toString(), new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				synchronized (getGraph()) {
					for (Vertex v : getGraph().getVertices()) {
						viewer.getPickedVertexState().pick(v, true);
					}
				}
			}
		});
		actionMap.put(CommandManager.Command.DeselectAll.toString(), new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				viewer.getPickedVertexState().clear();
			}
		});
		actionMap.put(CommandManager.Command.Relayout.toString(), new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				// re-layout
				initLayout.reset();
				forceLayout.forgetPositions();
				viewer.update();
				setVerticesPositionData();
			}
		});

		actionMap.put(CommandManager.Command.ExportToPdf.toString(), new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				exportToPdf();
			}
		});
		actionMap.put(CommandManager.Command.SelectMode.toString(), new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				graphMouse.setPickingMouse();
			}
		});
		actionMap.put(CommandManager.Command.DirectedEdgeMode.toString(), new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				directedEdges = true;
				graphMouse.setEdgeMouse();
			}
		});
		actionMap.put(CommandManager.Command.UndirectedEdgeMode.toString(), new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				directedEdges = false;
				graphMouse.setEdgeMouse();
			}
		});
		actionMap.put(CommandManager.Command.LatexToClipboard.toString(), new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				String tikz = TikzOutput.generate(
						getGraph(),
						viewer.getGraphLayout());
				Clipboard cb = Toolkit.getDefaultToolkit().getSystemClipboard();
				StringSelection data = new StringSelection(tikz);
				cb.setContents(data, data);
			}
		});
		actionMap.put(CommandManager.Command.AddBoundaryVertex.toString(), new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				addBoundaryVertex();
			}
		});
		actionMap.put(CommandManager.Command.ShowRewrites.toString(), new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				showRewrites();
			}
		});
		actionMap.put(CommandManager.Command.Normalise.toString(), new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				if (rewriter != null) {
					abortRewriting();
				}
				startRewriting();

			}
		});
		actionMap.put(CommandManager.Command.FastNormalise.toString(), new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				try {
					cacheVertexPositions();
					Rectangle2D rect = viewer.getGraphBounds();
					core.fastNormalise(getGraph());
					relayoutGraph(rect);
				} catch (CoreException ex) {
					coreErrorDialog("Could not normalise graph", ex);
				}
			}
		});
		actionMap.put(CommandManager.Command.BangVertices.toString(), new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				try {
					core.addBangBox(getGraph(), viewer.getPickedVertexState().getPicked());
				} catch (CoreException ex) {
					coreErrorDialog("Could not add !-box", ex);
				}
			}
		});
		actionMap.put(CommandManager.Command.UnbangVertices.toString(), new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				try {
					cacheVertexPositions();
					Rectangle2D rect = viewer.getGraphBounds();
					core.removeVerticesFromBangBoxes(getGraph(), viewer.getPickedVertexState().getPicked());
					relayoutGraph(rect);
				} catch (CoreException ex) {
					coreErrorDialog("Could not remove vertices from !-box", ex);
				}
			}
		});
		actionMap.put(CommandManager.Command.DropBangBox.toString(), new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				try {
					core.dropBangBoxes(getGraph(), viewer.getPickedBangBoxState().getPicked());
				} catch (CoreException ex) {
					coreErrorDialog("Could not remove !-box", ex);
				}
			}
		});
		actionMap.put(CommandManager.Command.KillBangBox.toString(), new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				try {
					core.killBangBoxes(getGraph(), viewer.getPickedBangBoxState().getPicked());
				} catch (CoreException ex) {
					coreErrorDialog("Could not kill !-box", ex);
				}
			}
		});
		actionMap.put(CommandManager.Command.DuplicateBangBox.toString(), new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				try {
					cacheVertexPositions();
					Rectangle2D rect = viewer.getGraphBounds();
					if (viewer.getPickedBangBoxState().getPicked().size() == 1) {
						core.duplicateBangBox(getGraph(), (BangBox) viewer.getPickedBangBoxState().getPicked().toArray()[0]);
					}
					updateGraph(rect);
				} catch (CoreException ex) {
					coreErrorDialog("Could not duplicate !-box", ex);
				}
			}
		});

		actionMap.put(CommandManager.Command.DumpHilbertTermAsText.toString(), new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				try {
					outputToTextView(core.hilbertSpaceRepresentation(getGraph(), Core.RepresentationType.Plain));
				} catch (CoreException ex) {
					coreErrorDialog("Could not create Hilbert term", ex);
				}
			}
		});
		actionMap.put(CommandManager.Command.DumpHilbertTermAsMathematica.toString(), new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				try {
					outputToTextView(core.hilbertSpaceRepresentation(getGraph(), Core.RepresentationType.Mathematica));
				} catch (CoreException ex) {
					coreErrorDialog("Could not create Hilbert term", ex);
				}
			}
		});
		actionMap.put(CommandManager.Command.Refresh.toString(), new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				try {
					core.updateGraph(getGraph());
				} catch (CoreException ex) {
					coreErrorDialog("Could not refresh graph", ex);
				}
			}
		});

		/*
		 * Add dynamically commands corresponding allowing to add registered vertices
		 */
		for (final VertexType vertexType : core.getActiveTheory().getVertexTypes()) {
			actionMap.put("add-" + vertexType.getTypeName() + "-vertex-command", new ActionListener() {

				public void actionPerformed(ActionEvent e) {
					addVertex(vertexType.getTypeName());
				}
			});
		}
	}

	@Override
	public void attached(ViewPort vp) {
		for (String actionName : actionMap.keySet()) {
			vp.setCommandEnabled(actionName, true);
		}
		if (saveEnabled) {
			vp.setCommandEnabled(CommandManager.Command.Save,
					!getGraph().isSaved());
		}
		if ((graphMouse.isEdgeMouse()) && (directedEdges)) {
			vp.setCommandStateSelected(CommandManager.Command.DirectedEdgeMode, true);
		} else if (graphMouse.isEdgeMouse()) {
			vp.setCommandStateSelected(CommandManager.Command.UndirectedEdgeMode, true);
		} else {
			vp.setCommandStateSelected(CommandManager.Command.SelectMode, true);
		}
		setupNormaliseAction(vp);
		super.attached(vp);
	}

	@Override
	public void detached(ViewPort vp) {
		vp.setCommandStateSelected(CommandManager.Command.SelectMode, true);

		for (String actionName : actionMap.keySet()) {
			vp.setCommandEnabled(actionName, false);
		}
		super.detached(vp);
	}

	@Override
	protected String getUnsavedClosingMessage() {
		return "Graph '" + getGraph().getCoreName() + "' is unsaved. Close anyway?";
	}

	@Override
	public boolean isSaved() {
		return getGraph().isSaved();
	}

	public void keyPressed(KeyEvent e) {
		// this listener only handles un-modified keys
		if (e.getModifiers() != 0) {
			return;
		}

		int delete = (QuantoApp.isMac) ? KeyEvent.VK_BACK_SPACE : KeyEvent.VK_DELETE;
		if (e.getKeyCode() == delete) {
			try {
				core.deleteEdges(
						getGraph(), viewer.getPickedEdgeState().getPicked());
				core.deleteVertices(
						getGraph(), viewer.getPickedVertexState().getPicked());

			} catch (CoreException err) {
				coreErrorMessage("Could not delete the vertex", err);
			} finally {
				// if null things are in the picked state, weird stuff
				// could happen.
				viewer.getPickedEdgeState().clear();
				viewer.getPickedVertexState().clear();
			}
		} else {
			switch (e.getKeyCode()) {
				case KeyEvent.VK_B:
					addBoundaryVertex();
					break;
				case KeyEvent.VK_E:
					if (graphMouse.isEdgeMouse()) {
						graphMouse.setPickingMouse();
					} else {
						graphMouse.setEdgeMouse();
					}
					break;
				case KeyEvent.VK_SPACE:
					showRewrites();
					break;
				//hotkey for force layout
				case KeyEvent.VK_A: {
					forceLayout.startModify();
					viewer.modifyLayout();
					forceLayout.endModify();
					setVerticesPositionData();
				}
				break;
			}
			VertexType v = core.getActiveTheory().getVertexTypeByMnemonic(e.getKeyChar());
			if (v != null) {
				addVertex(v.getTypeName());
			}
		}
	}

	public void keyReleased(KeyEvent e) {
	}

	public void keyTyped(KeyEvent e) {
	}
}
