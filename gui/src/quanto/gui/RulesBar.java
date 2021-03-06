package quanto.gui;

import quanto.core.CoreException;
import quanto.core.Ruleset;
import quanto.core.RulesetChangeListener;
import quanto.core.data.CoreGraph;
import quanto.core.data.Rule;
import quanto.core.protocol.userdata.RulePriorityRuleUserDataSerializer;

import javax.swing.*;
import java.awt.*;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.MouseAdapter;
import java.awt.event.MouseEvent;
import java.util.*;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Panel displaying a very simple rules interface.
 *
 * This just lists the rules, allowing them to be filtered
 * by tag, and enables/disables rules (individually, all at
 * once, or by tag).
 *
 * @author alex
 */
public class RulesBar extends JPanel {

	private final static Logger logger =
			Logger.getLogger("quanto.gui");

	private static class RuleDescription {

		public RuleDescription(String rulename, boolean active) {
			this.rulename = rulename;
			this.active = active;
		}
		public String rulename;
		public boolean active;

		@Override
		public String toString() {
			return rulename;
		}
	};
	private Ruleset ruleset;
	private ViewPort viewPort;
	private RulesetChangeListener listener = new RulesetChangeListener() {

		public void rulesAdded(Ruleset source, Collection<String> ruleNames) {
			try {
				if (tagsCombo.getSelectedIndex() != 0) {
					for (String rule : ruleset.getRulesByTag(tagsCombo.getSelectedItem().toString())) {
						if (ruleNames.contains(rule)) {
							rulesModel.addElement(new RuleDescription(rule,
									ruleset.isRuleActive(rule)));
						}
					}
				} else {
					for (String rule : ruleNames) {
						rulesModel.addElement(new RuleDescription(rule,
								ruleset.isRuleActive(rule)));
					}
				}
			} catch (CoreException ex) {
				logger.log(Level.WARNING, "Core complained when responding to rule addition", ex);
				ruleset.reload();
			}
		}

		public void rulesRemoved(Ruleset source, Collection<String> ruleNames) {
			Object[] descs = rulesModel.toArray();
			for (int i = 0; i < descs.length; ++i) {
				RuleDescription desc = (RuleDescription) descs[i];
				if (ruleNames.contains(desc.rulename)) {
					rulesModel.remove(i);
				}
			}
		}

		public void rulesRenamed(Ruleset source, Map<String, String> renaming) {
			Object[] descs = rulesModel.toArray();
			for (int i = 0; i < descs.length; ++i) {
				RuleDescription desc = (RuleDescription) descs[i];
				if (renaming.containsKey(desc.rulename)) {
					desc.rulename = renaming.get(desc.rulename);
					// force an update
					rulesModel.set(i, desc);
				}
			}
		}

		public void rulesetReplaced(Ruleset source) {
			loadTags();
			loadRules(tagsCombo.getSelectedItem().toString());
		}

		public void rulesActiveStateChanged(Ruleset source, Map<String, Boolean> newState) {
			Object[] descs = rulesModel.toArray();
			for (int i = 0; i < descs.length; ++i) {
				RuleDescription desc = (RuleDescription) descs[i];
				if (newState.containsKey(desc.rulename)) {
					desc.active = newState.get(desc.rulename);
					// force an update
					rulesModel.set(i, desc);
				}
			}
		}

		public void rulesTagged(Ruleset source, String tag, Collection<String> ruleNames, boolean newTag) {
			if (newTag) {
				tagsCombo.addItem(tag);
			}
			if (tagsCombo.getSelectedIndex() == 0) {
				return;
			}
			if (!tagsCombo.getSelectedItem().toString().equals(tag)) {
				return;
			}
			try {
				for (String rule : ruleNames) {
					rulesModel.addElement(new RuleDescription(rule,
							ruleset.isRuleActive(rule)));
				}
			} catch (CoreException ex) {
				logger.log(Level.WARNING, "Core complained when responding to rule tagging", ex);
				ruleset.reload();
			}
		}

		public void rulesUntagged(Ruleset source, String tag, Collection<String> ruleNames, boolean tagRemoved) {
			if (tagRemoved) {
				if (tagsCombo.getSelectedIndex() != 0
						&& tagsCombo.getSelectedItem().toString().equals(tag)) {
					tagsCombo.setSelectedIndex(0);
				}
				tagsCombo.removeItem(tag);
				return;
			}
			if (tagsCombo.getSelectedIndex() == 0) {
				return;
			}
			if (!tagsCombo.getSelectedItem().toString().equals(tag)) {
				return;
			}
			Object[] descs = rulesModel.toArray();
			for (int i = 0; i < descs.length; ++i) {
				RuleDescription desc = (RuleDescription) descs[i];
				if (ruleNames.contains(desc.rulename)) {
					rulesModel.remove(i);
				}
			}
		}
	};
	private JList listView;
	private DefaultListModel rulesModel;
	private JButton enableButton;
	private JButton disableButton;
	private JButton deleteButton;
	private JButton createRuleButton;
	private JButton refreshButton;
	private JComboBox tagsCombo;
	private boolean suppressTagComboCallback = false;

	private void showModalError(String message, CoreException ex) {
		logger.log(Level.SEVERE, message, ex);
		DetailedErrorDialog.showCoreErrorDialog(this, message, ex);
	}

	private void logError(String message, CoreException ex) {
		logger.log(Level.SEVERE, message, ex);
		// FIXME: show to user
	}

	private void logWarning(String message, CoreException ex) {
		logger.log(Level.WARNING, message, ex);
		// FIXME: show to user
	}

	private JPopupMenu createRuleContextualMenu() {
		Object[] objDescs = listView.getSelectedValues();
		final RuleDescription[] descs = new RuleDescription[objDescs.length];
		for (int i = 0; i < objDescs.length; ++i) {
			descs[i] = (RuleDescription)objDescs[i];
		}
		JPopupMenu popupMenu = new JPopupMenu();
		JMenuItem menuItem;
		
		if (descs.length == 1) {
			menuItem = new JMenuItem("Edit rule");
			popupMenu.add(menuItem);
			menuItem.addActionListener(new ActionListener() {
				public void actionPerformed(ActionEvent e) {
					editRule(descs[0].rulename);
				}
			});

			menuItem = new JMenuItem("Rename rule");
			popupMenu.add(menuItem);
			menuItem.addActionListener(new ActionListener() {
				public void actionPerformed(ActionEvent e) {
					renameRule(descs[0].rulename);
				}
			});
		}

		menuItem = new JMenuItem((descs.length == 1) ? "Delete rule" : "Delete rules");
		popupMenu.add(menuItem);
		menuItem.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				deleteSelectedRules();
			}
		});
		
		int enabledCount = 0;
		int disabledCount = 0;
		for (RuleDescription desc : descs) {
			if (desc.active)
				++enabledCount;
			else
				++disabledCount;
		}
		if (disabledCount > 0) {
			menuItem = new JMenuItem((descs.length == 1) ? "Enable rule" : "Enable rules");
			popupMenu.add(menuItem);
			menuItem.addActionListener(new ActionListener() {
				public void actionPerformed(ActionEvent e) {
					enableSelectedRules();
				}
			});
		}
		if (enabledCount > 0) {
			menuItem = new JMenuItem((descs.length == 1) ? "Disable rule" : "Disable rules");
			popupMenu.add(menuItem);
			menuItem.addActionListener(new ActionListener() {
				public void actionPerformed(ActionEvent e) {
					disableSelectedRules();
				}
			});
		}

		if (descs.length == 1) {
			menuItem = new JMenuItem("New Rule by Reverse");
			popupMenu.add(menuItem);
			menuItem.addActionListener(new ActionListener() {

				public void actionPerformed(ActionEvent e) {
					String name = JOptionPane.showInputDialog(RulesBar.this, "Rule name:",
							descs[0].rulename + "-rev");
					if (name == null) {
						return;
					}

					try {
						Rule rule = RulesBar.this.ruleset.getCore().openRule(descs[0].rulename);
						rule = RulesBar.this.ruleset.getCore().createRule(name, rule.getRhs(), rule.getLhs());
						SplitGraphView spg = new SplitGraphView(RulesBar.this.ruleset.getCore(), rule);
						RulesBar.this.viewPort.getViewManager().addView(spg);
						RulesBar.this.viewPort.attachView(spg);
					} catch (CoreException ex) {
						showModalError("Could not create a new rule.", ex);
					}
				}
			});
		}

		JMenu subMenu = new JMenu("Add tag");
		try {
			Collection<String> allTags = ruleset.getTags();
			for (String tag : allTags) {
				menuItem = new JMenuItem(tag);
				menuItem.addActionListener(new ActionListener() {
					public void actionPerformed(ActionEvent e) {
						try {
							for (RuleDescription desc : descs) {
								ruleset.tagRule(desc.rulename, e.getActionCommand());
							}
						} catch (CoreException ex) {
							showModalError("Could not tag the rule.", ex);
						}
					}
				});
				subMenu.add(menuItem);
			}
		} catch (CoreException ex) {
			logError("Could not load tags from the core.", ex);
		}
		menuItem = new JMenuItem("New Tag...");
		menuItem.addActionListener(new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				String tag = JOptionPane.showInputDialog(RulesBar.this, "Tag name:", "");
				if (tag == null) {
					return;
				}

				try {
					for (RuleDescription desc : descs) {
						ruleset.tagRule(desc.rulename, tag);
					}
				} catch (CoreException ex) {
					showModalError("Could not tag the rule.", ex);
				}
			}
		});
		subMenu.add(menuItem);
		popupMenu.add(subMenu);

		try {
			HashSet<String> tags = new HashSet<String>();
			for (RuleDescription desc : descs) {
				tags.addAll(ruleset.getRuleTags(desc.rulename));
			}
			if (!tags.isEmpty()) {
				subMenu = new JMenu("Remove tag");
				for (String tag : tags) {
					menuItem = new JMenuItem(tag);
					menuItem.addActionListener(new ActionListener() {

						public void actionPerformed(ActionEvent e) {
							try {
								for (RuleDescription desc : descs) {
									ruleset.untagRule(desc.rulename, e.getActionCommand());
								}
							} catch (CoreException ex) {
								showModalError("Could not load tags for the rule \""
										+ listView.getSelectedValue().toString()
										+ "\" from the core.", ex);
							}
						}
					});
					subMenu.add(menuItem);
				}
				popupMenu.add(subMenu);
			}
		} catch (CoreException ex) {
			logError("Could not load tags for the rule \""
					+ listView.getSelectedValue().toString()
					+ "\" from the core.", ex);
		}
		return popupMenu;
	}

	private ImageIcon createImageIcon(String path,
			String description) {
		java.net.URL imgURL = getClass().getResource(path);
		if (imgURL != null) {
			return new ImageIcon(imgURL, description);
		} else {
			logger.log(Level.WARNING, "Could not load image icon \"{0}\"", path);
			return null;
		}
	}
	
	private void enableSelectedRules() {
		try {
			Object[] descs = listView.getSelectedValues();
			List<String> ruleNames = new LinkedList<String>();
			for (Object d : descs) {
				ruleNames.add(((RuleDescription) d).rulename);
			}
			ruleset.activateRules(ruleNames);
		} catch (CoreException ex) {
			showModalError("Could not enable the rules.", ex);
		}
	}
	
	private void disableSelectedRules() {
		try {
			Object[] descs = listView.getSelectedValues();
			List<String> ruleNames = new LinkedList<String>();
			for (Object d : descs) {
				ruleNames.add(((RuleDescription) d).rulename);
			}
			ruleset.deactivateRules(ruleNames);
		} catch (CoreException ex) {
			showModalError("Could not disable the rules.", ex);
		}
	}

	private void createMenuButtons() {
		enableButton = new JButton(createImageIcon("/toolbarButtonGraphics/quanto/ComputeAdd16.gif", "Enable"));
		enableButton.setToolTipText("Enable selected rules");
		enableButton.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				enableSelectedRules();
			}
		});

		disableButton = new JButton(createImageIcon("/toolbarButtonGraphics/quanto/ComputeRemove16.gif", "Disable"));
		disableButton.setToolTipText("Disable selected rules");
		disableButton.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				disableSelectedRules();
			}
		});

		deleteButton = new JButton(createImageIcon("/toolbarButtonGraphics/general/Delete16.gif", "Enable"));
		deleteButton.setToolTipText("Delete selected rules");
		deleteButton.addActionListener(new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				deleteSelectedRules();
			}
		});

		refreshButton = new JButton(createImageIcon("/toolbarButtonGraphics/general/Refresh16.gif", "Refresh"));
		refreshButton.setToolTipText("Reload ruleset");
		refreshButton.addActionListener(new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				RulesBar.this.ruleset.reload();
			}
		});

		createRuleButton = new JButton(createImageIcon("/toolbarButtonGraphics/general/New16.gif", "Create Rule"));
		createRuleButton.setToolTipText("Create Rule");
		createRuleButton.addActionListener(new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				String ruleName = JOptionPane.showInputDialog(RulesBar.this, "Rule name:", "");
				if (ruleName == null || ruleName.isEmpty()) {
					return;
				}
				try {
					CoreGraph lhs = RulesBar.this.ruleset.getCore().createEmptyGraph();
					CoreGraph rhs = RulesBar.this.ruleset.getCore().createEmptyGraph();
					Rule rule = RulesBar.this.ruleset.getCore().createRule(ruleName, lhs, rhs);

					SplitGraphView spg = new SplitGraphView(RulesBar.this.ruleset.getCore(), rule);
					RulesBar.this.viewPort.getViewManager().addView(spg);
					RulesBar.this.viewPort.attachView(spg);

					//By default the priority is set to 5
					RulePriorityRuleUserDataSerializer priorityRuleUserDataSerializer =
							new RulePriorityRuleUserDataSerializer(RulesBar.this.ruleset.getCore().getTalker());
					priorityRuleUserDataSerializer.setRuleUserData(ruleName, 5);
				} catch (CoreException ex) {
					showModalError("Could not create a new rule.", ex);
				}
			}
		});
	}

	public RulesBar(Ruleset ruleset, ViewPort viewPort) {
		this.ruleset = ruleset;
		this.viewPort = viewPort;
		ruleset.addRulesetChangeListener(listener);

		final DefaultListCellRenderer cellRenderer = new DefaultListCellRenderer() {

			@Override
			public Component getListCellRendererComponent(
					JList list,
					Object value,
					int index,
					boolean isSelected,
					boolean cellHasFocus) {
				super.getListCellRendererComponent(list, value.toString(),
						index, isSelected, cellHasFocus);
				setName(value.toString());
				if (!((RuleDescription) value).active) {
					setForeground(Color.gray);
				}

				return this;
			}
		};

		rulesModel = new DefaultListModel();
		listView = new JList(rulesModel);
		listView.setCellRenderer(cellRenderer);
		listView.addMouseListener(new MouseAdapter() {

			@Override
			public void mousePressed(MouseEvent e) {
				if (e.isPopupTrigger()) {
					int index = listView.locationToIndex(e.getPoint());
					if (index < 0) {
						return;
					}
					if (Arrays.binarySearch(listView.getSelectedIndices(), index) < 0) {
						listView.setSelectedIndex(index);
					}
					JPopupMenu contextualMenu = createRuleContextualMenu();
					contextualMenu.show(e.getComponent(),
							e.getX(), e.getY());
				}
			}
		});
		JScrollPane listPane = new JScrollPane(listView);
		tagsCombo = new JComboBox();
		createMenuButtons();



		tagsCombo.addActionListener(new ActionListener() {

			public void actionPerformed(ActionEvent e) {
				if (!suppressTagComboCallback) {
					JComboBox cb = (JComboBox) e.getSource();
					String tag = (String) cb.getSelectedItem();
					loadRules(tag);
				}
			}
		});

		JPanel buttonBox = new JPanel();
		buttonBox.setLayout(new BoxLayout(buttonBox, BoxLayout.LINE_AXIS));
		buttonBox.add(enableButton);
		buttonBox.add(disableButton);
		buttonBox.add(deleteButton);
		buttonBox.add(createRuleButton);
		buttonBox.add(refreshButton);
		this.setLayout(new BoxLayout(this, BoxLayout.PAGE_AXIS));
		this.add(buttonBox);
		this.add(tagsCombo);
		/*Because of the BoxLayout, the Jcombobox takes too much space
		width = width of the listPane, height = preferred height*/
		tagsCombo.setMaximumSize(new Dimension((int) listPane.getPreferredSize().getWidth(), (int) tagsCombo.getPreferredSize().getHeight()));
		this.add(listPane);

		loadTags();
		loadRules("All Rules");
	}

	private void editRule(String rule) {

		try {
			InteractiveViewManager vm = RulesBar.this.viewPort.getViewManager();
			for (Map.Entry<String,InteractiveView> e : vm.getViews().entrySet()) {
				if (e.getValue() instanceof SplitGraphView) {
					SplitGraphView sgv = (SplitGraphView)e.getValue();
					if (sgv.getRule().getCoreName().equals(rule)) {
						RulesBar.this.viewPort.attachView(sgv);
						return;
					}
				}
			}
			Rule ruleGraphs = RulesBar.this.ruleset.getCore().openRule(rule);
			SplitGraphView spg = new SplitGraphView(RulesBar.this.ruleset.getCore(), ruleGraphs);
			vm.addView(spg);
			RulesBar.this.viewPort.attachView(spg);
		} catch (CoreException ex) {
			showModalError("Cannot open the rule \"" + rule + "\"", ex);
		}
	}

	private void renameRule(String rule) {

		try {
			String newName = JOptionPane.showInputDialog(this,
					"Enter a new name for the rule \"" + rule + "\"", rule);
			if (newName != null && !newName.isEmpty()) {
				ruleset.renameRule(rule, newName);
			}
		} catch (CoreException ex) {
			showModalError("Cannot rename the rule \"" + rule + "\"", ex);
		}
	}

	private void deleteSelectedRules() {
		int confirmation = JOptionPane.showConfirmDialog(
				this,
				"Delete selected rule(s)?",
				"Delete Rules",
				JOptionPane.YES_NO_OPTION);
		if (confirmation != JOptionPane.YES_OPTION) {
			return;
		}
		try {
			Object[] descs = listView.getSelectedValues();
			for (Object d : descs) {
				ruleset.deleteRule(((RuleDescription) d).rulename);
			}
		} catch (CoreException ex) {
			showModalError("Cannot delete the selected rules", ex);
		}
	}

	private void loadTags() {
		try {
			try {
				suppressTagComboCallback = true;
				String oldSelection = null;
				if (tagsCombo.getItemCount() > 0) {
					oldSelection = tagsCombo.getSelectedItem().toString();
					tagsCombo.removeAllItems();
				}
				tagsCombo.addItem("All Rules");
				for (String tag : ruleset.getTags()) {
					tagsCombo.addItem(tag);
				}
				if (oldSelection != null) {
					for (int i = 0; i < tagsCombo.getItemCount(); ++i) {
						if (oldSelection.equals(tagsCombo.getItemAt(i).toString())) {
							tagsCombo.setSelectedIndex(i);
						}
					}
				}
			} finally {
				suppressTagComboCallback = false;
			}
		} catch (CoreException ex) {
			logError("Could not get tags from core", ex);
		}
	}

	private void loadRules(String tag) {
		rulesModel.clear();
		/* If the tag exists, load the corresponding rules.
		If not then load all the rules.*/
		try {
			if (tagsCombo.getSelectedIndex() != 0) {
				for (String rule : ruleset.getRulesByTag(tag)) {
					rulesModel.addElement(new RuleDescription(rule,
							ruleset.isRuleActive(rule)));
				}
			} else {
				for (String rule : ruleset.getRules()) {
					rulesModel.addElement(new RuleDescription(rule,
							ruleset.isRuleActive(rule)));
				}
			}
		} catch (CoreException ex) {
			logError("Could not get the rules for tag \""
					+ tag + "\" from core", ex);
		}
	}
}
