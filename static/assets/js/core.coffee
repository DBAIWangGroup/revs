########################################################################################
# Core math library for computations on knowledge graphs
########################################################################################
core = {}
window.core = core

global =
  next_visual_node_id: 1

core.triples_to_adj_lists = (triples)->
  adj_lists = {}
  for triple in triples
    s = triple.s
    p = triple.p
    o = triple.o
    s_adj_list = adj_lists[s]
    o_adj_list = adj_lists[o]
    if s_adj_list == undefined
      s_adj_list = []
      adj_lists[s] = s_adj_list
    if o_adj_list == undefined
      o_adj_list = []
      adj_lists[o] = o_adj_list
    s_adj_list.push
      predicate: p
      node: o
      is_outgoing: true
    o_adj_list.push
      predicate: p
      node: s
      is_outgoing: false
  return adj_lists

core.get_predicate_priority = (triples)->
  counts = {}
  for triple in triples
    count = counts[triple.p] or 0
    counts[triple.p] = count + 1
  priority = []
  for predicate, count of counts
    priority.push
      predicate: predicate
      score: count
  priority.sort (a, b)-> b.score - a.score
  return priority

core.get_node_set = (triples)->
  nodes = {}
  for triple in triples
    nodes[triple.s] = true
    nodes[triple.o] = true
  return nodes
  
core.get_clean_type_dict = (type_dict, node_set)->
  type_dict_copy = {}
  for node, types of type_dict
    if node of node_set
      type_dict_copy[node] = types
  return type_dict_copy

core.get_init_partition = (nodes, source, target, type_dict, type_info)->
  partition = []
  other_nodes = []
  for node of nodes
    if node != source and node != target
      other_nodes.push(node)
    else
      block = {}
      block[node] = true
      partition.push(block)
  type_blocks = {}
  others_block = {}
  for node in other_nodes
    node_types = type_dict[node]
    block_assigned = false
    for type in node_types
      if type_info.types[type].active
        target_block = type_blocks[type]
        if target_block == undefined
          target_block = {}
          type_blocks[type] = target_block
          partition.push(target_block)
        target_block[node] = true
        block_assigned = true
        break
    if not block_assigned
      others_block[node] = true
  if Object.keys(others_block).length > 0
    partition.push(others_block)
  return partition

core.get_type_info = (type_dict)->
  # assume each dict item contains a list of types which are leaf-type, parent-type, grandparent-type and so on,
  # and the last type in this list is the root type in the hierarchy tree
  type_info =
    root : undefined
    types : {}
  for node, node_types of type_dict
    if type_info.root == undefined
      type_info.root = node_types[node_types.length - 1]
    child_type = undefined
    for type in node_types
      info = type_info.types[type]
      if info == undefined
        info =
          count: 0
          children: {}
        type_info.types[type] = info
      if child_type != undefined
        info.children[child_type] = true
      info.count += 1
      child_type = type
  root_info = type_info.types[type_info.root]
  root_info.active = true
  root_info.locked = true
  return type_info

core.compute_type_hierarchy_view = (type_info)->
  visual_items = []
  root_id = type_info.root
  root_info = type_info.types[root_id]
  visual_items.push
    id: root_id
    depth: 0
    data: root_info
  compute_sub_hierarchy_view(root_info.children, type_info, 1, visual_items)
  return visual_items

compute_sub_hierarchy_view = (children, type_info, depth, visual_items)->
  for type of children
    info = type_info.types[type]
    visual_items.push
      id: type
      depth: depth
      data: info
    compute_sub_hierarchy_view(info.children, type_info, depth + 1, visual_items)

core.random_refinement = (partition)->
  candidate_blocks = []
  for block, i in partition
    if Object.keys(block).length == 1
      continue
    candidate_blocks.push
      index: i
      block: block
  if candidate_blocks.length == 0
    return
  target_block = candidate_blocks[Math.floor(Math.random() * candidate_blocks.length)]
  new_block_a = {}
  new_block_b = {}
  size_a = 0
  size_b = 0
  for node of target_block.block
    if Math.random() > 0.5
      new_block_a[node] = true
      ++size_a
    else
      new_block_b[node] = true
      ++size_b
  if size_a == 0
    block_b_nodes = Object.keys(new_block_b)
    transfer_node = block_b_nodes[Math.floor(Math.random() * block_b_nodes.length)]
    new_block_a[transfer_node] = true
    delete new_block_b[transfer_node]
  if size_b == 0
    block_a_nodes = Object.keys(new_block_a)
    transfer_node = block_a_nodes[Math.floor(Math.random() * block_a_nodes.length)]
    new_block_b[transfer_node] = true
    delete new_block_a[transfer_node]
  partition.splice(target_block.index, 1, new_block_a, new_block_b)

core.random_generalisation = (partition, source, target)->
  candidate_blocks = []
  for block, i in partition
    if block[source] or block[target]
      continue
    candidate_blocks.push
      index: i
      block: block
  if candidate_blocks.length < 2
    return
  target_block_a_index = Math.floor(Math.random() * candidate_blocks.length)
  target_block_a = candidate_blocks[target_block_a_index]
  candidate_blocks.splice(target_block_a_index, 1)
  target_block_b = candidate_blocks[Math.floor(Math.random() * candidate_blocks.length)]
  new_block = {}
  for node of target_block_a.block
    new_block[node] = true
  for node of target_block_b.block
    new_block[node] = true
  if target_block_a.index > target_block_b.index
    partition.splice(target_block_a.index, 1)
    partition.splice(target_block_b.index, 1)
  else
    partition.splice(target_block_b.index, 1)
    partition.splice(target_block_a.index, 1)
  partition.push(new_block)

core.compute_view_model = (adj_lists, type_dict, partition, old_model)->
  old_visual_nodes = if old_model != undefined then old_model.nodes else undefined
  visual_nodes = compute_visual_nodes(partition, type_dict, old_visual_nodes)
  visual_node_label_dict = build_label_dict(visual_nodes)
  visual_adj_lists = compute_visual_adj_lists(adj_lists, visual_nodes)
  model =
    nodes: visual_nodes
    label_dict: visual_node_label_dict
    adj_lists: visual_adj_lists
    nodes_added: []
    nodes_removed: []
    edges_added: []
    edges_removed: []
  if old_model == undefined
    model.nodes_added = visual_nodes
    for visual_node in visual_nodes
      for edge in visual_adj_lists[visual_node.id]
        if edge.is_outgoing
          model.edges_added.push
            source: visual_node.id
            target: edge.node
            predicate: edge.predicate
  else
    # given visual node list is already sorted with id
    diff = sorted_array_diff(old_model.nodes, visual_nodes, visual_node_compare)
    model.nodes_added = diff.added
    model.nodes_removed = diff.removed
    for added_node in model.nodes_added
      for edge in visual_adj_lists[added_node.id]
        if edge.is_outgoing
          model.edges_added.push
            source: added_node.id
            target: edge.node
            predicate: edge.predicate
    for removed_node in model.nodes_removed
      for edge in old_model.adj_lists[removed_node.id]
        if edge.is_outgoing
          model.edges_removed.push
            source: removed_node.id
            target: edge.node
            predicate: edge.predicate
    for kept_node in diff.kept
      kept_id = kept_node.id
      old_adj_list = old_model.adj_lists[kept_id]
      adj_list = visual_adj_lists[kept_id]
      # given adjacent list (edge list) is already sorted with edge_compare function
      edge_diff = sorted_array_diff(old_adj_list, adj_list, edge_compare)
      for added_edge in edge_diff.added
        if added_edge.is_outgoing
          model.edges_added.push
            source: kept_id
            target: added_edge.node
            predicate: added_edge.predicate
      for removed_edge in edge_diff.removed
        if removed_edge.is_outgoing
          model.edges_removed.push
            source: kept_id
            target: removed_edge.node
            predicate: removed_edge.predicate
  model.nodes_to_group = build_node_to_group_dict(model.nodes)
  return model

build_node_to_group_dict = (visual_nodes)->
  nodes_to_group = {}
  for visual_node in visual_nodes
    for node in visual_node.nodes
      nodes_to_group[node] = visual_node.id
  return nodes_to_group

build_label_dict = (visual_nodes)->
  dict = {}
  for node in visual_nodes
    dict[node.id] = node.label
  return dict

visual_node_compare = (a, b)-> a.id.localeCompare(b.id)

edge_compare = (a, b)->
  cmp = a.predicate.localeCompare(b.predicate)
  if cmp != 0
    return cmp
  cmp = a.node.localeCompare(b.node)
  if cmp != 0
    return cmp
  if a.is_outgoing
    return if b.is_outgoing then 0 else 1
  else
    return if b.is_outgoing then -1 else 0

sorted_array_diff = (a, b, compare_func)->
  # assume  a and b are already sorted with compare_func, return change from a to b
  result =
    added: []
    removed: []
    kept: []
  i = 0
  j = 0
  m = a.length
  n = b.length
  while i < m and j < n
    ele_a = a[i]
    ele_b = b[j]
    cmp = compare_func(ele_a, ele_b)
    if cmp == 0
      result.kept.push(ele_a)
      ++i
      ++j
    else if cmp < 0
      result.removed.push(ele_a)
      ++i
    else
      result.added.push(ele_b)
      ++j
  while i < m
    ele_a = a[i]
    result.removed.push(ele_a)
    ++i
  while j < n
    ele_b = b[j]
    result.added.push(ele_b)
    ++j
  return result

compute_visual_adj_lists = (adj_lists, visual_nodes)->
  visual_adj_lists = {}
  node_to_visual_node_dict = {}
  for visual_node in visual_nodes
    visual_adj_lists[visual_node.id] = []
    for node in visual_node.nodes
      node_to_visual_node_dict[node] = visual_node
  for node, adj_list of adj_lists
    visual_adj_list = visual_adj_lists[node_to_visual_node_dict[node].id]
    for edge in adj_list
      visual_edge =
        predicate: edge.predicate
        node: node_to_visual_node_dict[edge.node].id
        is_outgoing: edge.is_outgoing
      is_new_visual_edge = true
      for existing_visual_edge in visual_adj_list
        if edge_compare(visual_edge, existing_visual_edge) == 0
          is_new_visual_edge = false
          break
      if is_new_visual_edge
        visual_adj_list.push(visual_edge)
  for node, adj_list of visual_adj_lists
    adj_list.sort(edge_compare) # ensure edges are sorted
  return visual_adj_lists

compute_visual_nodes = (partition, type_dict, old_visual_nodes) ->
  old_visual_nodes_to_compare = undefined
  if old_visual_nodes != undefined
    old_visual_nodes_to_compare = []
    for old_visual_node in old_visual_nodes
      old_visual_nodes_to_compare.push(old_visual_node)
  visual_nodes = []
  for node_set in partition
    nodes = Object.keys(node_set)
    if nodes.length == 1
      visual_nodes.push
        id: nodes[0]
        label: nodes[0]
        nodes: nodes
    else
      nodes.sort() # IMPORTANT! node list also sorted
      matched_old_visual_node = undefined
      if old_visual_nodes_to_compare != undefined
        match_found = false
        match_node_index = undefined
        for old_visual_node, i in old_visual_nodes_to_compare
          if old_visual_node.nodes.length != nodes.length
            continue
          match_found = true
          for old_node,j in old_visual_node.nodes
            if nodes[j] != old_node # given node list of a visual node is already sorted
              match_found = false
              break
          if match_found
            matched_old_visual_node = old_visual_node
            match_node_index = i
            break
        if match_found
          old_visual_nodes_to_compare.splice(match_node_index, 1)
      if matched_old_visual_node == undefined
        visual_nodes.push
          id: '?v' + (global.next_visual_node_id++)
          label: get_block_label(nodes, type_dict)
          nodes: nodes
      else
        visual_nodes.push
          id: matched_old_visual_node.id
          label: matched_old_visual_node.label
          nodes: nodes
  # return a list sorted with node id
  return visual_nodes.sort(visual_node_compare)


get_block_label = (nodes, type_dict)->
  type_summary = {}
  for node in nodes
    node_type = type_dict[node][0]
    if node_type not of type_summary
      type_summary[node_type] = 1
    else
      type_summary[node_type] += 1
  sorted_types = ({
    "type": type,
    "count": type_summary[type]
  } for type of type_summary).sort (a, b)-> b['count'] - a['count']
  top_types = sorted_types.slice(0, 3)
  top_type_names = (item['type'] for item in top_types)
  label = top_type_names.join('/')
  if sorted_types.length > 3
    label += '/…'
  return label