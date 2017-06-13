########################################################################################
# Javascript implementation for computing the Bisimulations
########################################################################################
simulation = {}
window.simulation = simulation

simulation.get_coarsest_partition = (adj_lists, node_set, initial_partition, predicate)->
  q = get_init_q(adj_lists, node_set, initial_partition, predicate)
  x = [node_set]
  while true
    s_index = find_s_index(q, x)
    if s_index == null
      break
    s = x[s_index]
    b = find_b(q, s)
    s_minus_b = set_diff(s,b)
    x.push(b)
    x.push(s_minus_b)
    x.splice(s_index, 1)
    pre_b = get_pre_image(adj_lists, b, predicate)
    pre_s_minus_b = get_pre_image(adj_lists, s_minus_b, predicate)
    q_prime = []
    for d in q
      d11 = set_intersection(set_intersection(d, pre_b), pre_s_minus_b)
      d12 = set_intersection(d, set_diff(pre_b, pre_s_minus_b))
      d2 = set_diff(d, pre_b)
      if Object.keys(d11).length > 0
        q_prime.push(d11)
      if Object.keys(d12).length > 0
        q_prime.push(d12)
      if Object.keys(d2).length > 0
        q_prime.push(d2)
    q = q_prime
  if not simulation.is_stable_partition(adj_lists, q, predicate)
    console.error('Result is not stable!')
  return q

simulation.is_stable_partition = (adj_lists, partition, predicate)->
  for s in partition
    pre_s = get_pre_image(adj_lists, s, predicate)
    for b in partition
      diff_size = Object.keys(set_diff(b - pre_s)).length
      if diff_size != Object.keys(b).length and diff_size != 0
        return false
  return true

set_diff = (a, b)->
  diff = {}
  for item of a
    if item not of b
      diff[item] = true
  return diff

set_intersection = (a, b)->
  inter = {}
  for item of a
    if item of b
      inter[item] = true
  return inter

is_subset = (a,b)->
  for item of a
    if item not of b
      return false
  return true

get_init_q = (adj_lists, node_set, initial_partition, predicate)->
  q = []
  pre_u = get_pre_image(adj_lists, node_set, predicate)
  for d in initial_partition
    d1 = set_intersection(d, pre_u)
    d2 = set_diff(d, pre_u)
    if Object.keys(d1).length > 0
      q.push(d1)
    if Object.keys(d2).length > 0
      q.push(d2)
  return q

get_pre_image = (adj_lists, nodes, predicate)->
  pre_b = {}
  for node of nodes
    for edge in adj_lists[node]
      if predicate == undefined  # ignore edge label and direction
        pre_b[edge.node] = true
      else if edge.predicate == predicate and not edge.is_outgoing  # considering edge label and direction
        pre_b[edge.node] = true
  return pre_b

find_s_index = (q, x)->
  for x_block,i in x
    for q_block in q
      if is_subset(q_block, x_block) and Object.keys(q_block).length < Object.keys(x_block).length
        return i
  return null

find_b = (q, s)->
  subset_count = 0
  b_candidates = []
  for block,i in q
    if is_subset(block, s)
      subset_count += 1
      b_candidates.push(block)
      if subset_count == 2
        if Object.keys(b_candidates[0]).length <= Object.keys(b_candidates[1]).length
          return b_candidates[0]
        else
          return b_candidates[1]