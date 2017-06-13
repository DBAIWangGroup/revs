########################################################################################
# Graph library initializer
########################################################################################
setup_cy = (container)->
  cy = window.cy = cytoscape
    container: container
    minZoom: 0.1
    maxZoom: 4
    style: [
      {
        selector: 'node'
        style:
          'content': 'data(name)'
          'width': (e)-> Math.sqrt((e.data('nodes') || [0]).length) * 20
          'height': (e)-> Math.sqrt((e.data('nodes') || [0]).length) * 20
          'text-valign': 'center'
          'text-halign': 'right'
          'background-color': (e)-> if e.data('is_compound') then '#337ab7' else '#11479e'
          'transition-duration': "100ms"
          'transition-property': "font-size,background-color"
          'border-style': 'dotted'
          'border-color': '#11479e'
          'border-width': (e)-> if e.data('is_compound') then 3 else 0
      },
      {
        selector: 'edge'
        style:
          'content': 'data(name)'
          'opacity': 0.6
          'width': 2
          'target-arrow-shape': 'triangle'
          'line-color': 'lightgrey'
          'target-arrow-color': 'lightgrey'
          'transition-duration': "100ms"
          'transition-property': "opacity,line-color,color,target-arrow-color"
      },
      {
        selector: 'node.source'
        style:
          'background-color': '#5cb85c'
      },
      {
        selector: 'node.target'
        style:
          'background-color': '#d9534f'
      },
      {
        selector: 'node.hovered'
        style:
          'font-size': 24
      },
      {
        selector: 'edge.enabled'
        style:
          'line-color': '#9dbaea'
          'target-arrow-color': '#9dbaea'
          'width': 4
      },
      {
        selector: 'edge.hovered'
        style:
          'opacity': 1.0
      },
      {
        selector: 'node:selected'
        style:
          'border-style': 'double'
          'border-color': 'purple'
          'border-width': '6'
      },
      {
        selector: 'node.highlighted'
        style:
          'background-color': '#FFEB3B'
      },
      {
        selector: 'edge.highlighted'
        style:
          'line-color': '#FFEB3B'
          'color': 'orange'
          'target-arrow-color': '#FFEB3B'
          'opacity': 1
      }
    ]
  cy.on 'mouseover', 'node, edge', (event)-> event.cyTarget.addClass('hovered')
  cy.on 'mouseout', 'node, edge', (event)-> event.cyTarget.removeClass('hovered')
  return cy

cy_default_padding = 52
cy_layouts = [
  {name: 'random'},
  {name: 'grid'},
  {name: 'circle'},
  {name: 'concentric'},
  {name: 'breadthfirst'},
  {name: 'dagre'},
  {name: 'spread'},
  {name: 'cose'},
  {name: 'cose-bilkent'},
  {name: 'cola'}
];
for layout in cy_layouts
  layout.padding = cy_default_padding

########################################################################################
# Utility functions
########################################################################################
b64toBlob = (b64Data, contentType, sliceSize) ->
  contentType = contentType or ''
  sliceSize = sliceSize or 512
  byteCharacters = atob(b64Data)
  byteArrays = []
  for offset in [0..byteCharacters.length - 1] by sliceSize
    slice = byteCharacters.slice(offset, offset + sliceSize)
    byteNumbers = new Array(slice.length)
    for i in [0..slice.length - 1]
      byteNumbers[i] = slice.charCodeAt(i)
    byteArray = new Uint8Array(byteNumbers)
    byteArrays.push(byteArray)
  blob = new Blob(byteArrays, {type: contentType})
  return blob

objToBlob = (obj, beautiful)->
  json = JSON.stringify(obj, null, if beautiful then 4 else 0)
  return new Blob([json], {type: 'application/json;charset=UTF-8'})

save_canvas = (file_name)->
  data = cy.png
    bg: 'white'
  .replace(/^data:image\/\w+;base64,/, "")
  blob = b64toBlob(data, 'image/png')
  saveAs(blob, file_name)

show_input_hint = (input, content)->
  setTimeout ()->
    input.focus().popover
      content: content
      container: 'body'
      placement: 'bottom'
    .popover('show')
    .one 'keydown blur', -> $(@).popover('destroy')
  , 300


format_response_error = (response)->
  if !!response.data and !!response.data.error
    return response.data.error
  else if response.status == -1
    return "Oops, we have a connection problem..."
  else
    return '[' + response.status + '] ' + response.statusText


########################################################################################
# AngularJs App module
########################################################################################
angular.module 'app', ['ngRoute', 'ngSanitize']
.config ['$routeProvider', ($routeProvider)->
  $routeProvider.when '/',
    templateUrl: '/static/parts/home.html'
    controller: 'HomeController'
  .when '/explain',
    templateUrl: '/static/parts/explain.html'
    controller: 'ExplainController'
  .when '/explore',
    templateUrl: '/static/parts/explore.html'
    controller: 'ExploreController'
  .otherwise
      templateUrl: '/static/parts/404.html'
]

########################################################################################
# Customized AngularJs filters
########################################################################################
.filter 'reverse', ->
  (items) ->
    if !!items and typeof(items.slice) == 'function'
      return items.slice().reverse()
    return items

########################################################################################
# AngularJs directives
########################################################################################
.directive 'navBar', ->
  restrict: 'A'
  templateUrl: '/static/parts/nav-bar.html'

.directive 'modals', ->
  restrict: 'A'
  templateUrl: '/static/parts/modals.html'

.directive 'entityInput', ->
  restrict: 'A'
  scope:
    item: '='
  link: (scope, element, attrs)->
    $(element).typeahead
      source: (query, process)->
        $.getJSON 'api/entity?q=' + encodeURIComponent(query), (data)->
          process(data)
      afterSelect: (item)->
        base = 'http://dbpedia.org/resource/'
        url = item.url
        if url.startsWith(base)
          url = url.substring(base.length)
        scope.$apply ->
          scope.item = url
      items: 'all'


########################################################################################
# AngularJs Controllers
########################################################################################
.controller 'RootController', ['$scope', '$location', '$http', ($scope, $location, $http)->
  $scope.app =
    name: 'REVS'
    copyright: ''#'Copyright © Kelvin Miao, 2016. Supervised by Prof. Wei Wang and Dr. Jianbin Qin, UNSW.'
    quote:
      author: 'Christopher Strachey'
      title: 'A letter to Alan Turing, 1954'
      content: 'I am convinced that the crux of the problem of learning is recognizing relationships and being able to use them.'
  $scope.ui =
    showNav: false
    navMode: 'explain'
    authMode: 'signIn'
  $scope.auth =
    user: undefined
  $scope.state =
    querying_explain: false
    querying_explore: false
  $scope.config =
    defaultMaxLength: 3
    maxLengths: [2, 3, 4]
  $scope.query =
    source: undefined
    target: undefined
    maxLength: $scope.config.defaultMaxLength
  $scope.getExplainURL = (source, target, maxLength)->
    source = encodeURIComponent(source)
    target = encodeURIComponent(target)
    maxLength = maxLength or $scope.config.defaultMaxLength
    return "/explain?source=#{source}&target=#{target}&maxLength=#{maxLength}"
  $scope.getExploreURL = (entity)->
    entity = encodeURIComponent(entity)
    return "/explore?node=#{entity}"
  $scope.goExplain = ->
    $location.url($scope.getExplainURL($scope.query.source, $scope.query.target, $scope.query.maxLength))
  $scope.goExplore = (item)->
    if item == 'source'
      $location.url($scope.getExploreURL($scope.query.source))
    else if item == 'target'
      $location.url($scope.getExploreURL($scope.query.target) + "&from=target")
  $scope.$on 'requestModal', (event, args...)->
    $scope.$broadcast 'showModal', args...
  $http.get('api/users/me').then (response)-> $scope.auth.user = response.data
]

.controller 'AuthModalController', ['$scope', '$http', ($scope, $http)->
  $scope.forms =
    signIn: {}
    signUp: {}
    signOut: {}
  $modal = $('#auth_modal')
  $scope.$on 'showModal', (event, modal, mode)->
    if modal == 'auth'
      $scope.ui.authMode = mode
      $modal.modal('show')
      return
  $scope.signIn = ->
    form = $scope.forms.signIn
    form.error = undefined
    if form.name == undefined or form.name.length == 0
      form.error = 'User name is required'
      return
    if form.password == undefined or form.password.length == 0
      form.error = 'Password is required'
      return
    $btnSubmit = $('#btn_sign_in_submit')
    $btnSubmit.button('loading')
    $http.post('api/users/login',
      name: form.name
      password: form.password
    ).then (response)->
      $btnSubmit.button('reset')
      $scope.auth.user = response.data
      $modal.modal('hide')
    , (response)->
      $btnSubmit.button('reset')
      form.error = format_response_error(response)
  $scope.signUp = ->
    form = $scope.forms.signUp
    form.error = undefined
    if form.name == undefined or form.name.length == 0
      form.error = 'User name is required'
      return
    if form.password == undefined or form.password.length == 0
      form.error = 'Password is required'
      return
    if form.password_again != form.password
      form.error = 'Two passwords didn\'t match'
      return
    $btnSubmit = $('#btn_sign_up_submit')
    $btnSubmit.button('loading')
    $http.post('api/users/register',
      name: form.name
      password: form.password
    ).then (response)->
      $btnSubmit.button('reset')
      $scope.auth.user = response.data
      $modal.modal('hide')
    , (response)->
      $btnSubmit.button('reset')
      form.error = format_response_error(response)
  $scope.signOut = ->
    form = $scope.forms.signOut
    form.error = undefined
    $btnSubmit = $('#btn_sign_out_submit')
    $btnSubmit.button('loading')
    $http.get('api/users/logout').then (response)->
      $btnSubmit.button('reset')
      $scope.auth.user = undefined
      $modal.modal('hide')
    , (response)->
      $btnSubmit.button('reset')
      form.error = format_response_error(response)
]

.controller 'NavBarController', ['$scope', '$http', '$timeout', ($scope, $http, $timeout)->
  $source = $('#nav_entity_source')
  $target = $('#nav_entity_target')
  $scope.explain = ->
    q = $scope.query
    if(q.source == undefined or q.source.length == 0 )
      show_input_hint($source, 'Please give me the source entity!')
      return
    if(q.target == undefined or q.target.length == 0 )
      show_input_hint($target, 'Please give me the target entity!')
      return
    $scope.goExplain()
  $scope.explore_source = ->
    q = $scope.query
    if(q.source == undefined or q.source.length == 0 )
      show_input_hint($source, 'Please give me the source entity!')
      return
    $scope.goExplore('source')
  $scope.explore_target = ->
    q = $scope.query
    if(q.target == undefined or q.target.length == 0 )
      show_input_hint($target, 'Please give me the target entity!')
      return
    $scope.goExplore('target')
  $scope.switchExplainMode = ->
    oldMode = $scope.ui.navMode
    $scope.ui.navMode = 'explain'
    if(oldMode == 'explore_source')
      $timeout(->
        $target.focus()
      , 200)
    else if(oldMode == 'explore_target')
      $timeout(->
        $source.focus()
      , 200)
  $scope.showAuthModal = (mode)->
    $scope.$emit('requestModal', 'auth', mode)
]

.controller 'HomeController', ['$scope', '$http', '$location', ($scope, $http, $location)->
  $scope.ui.showNav = false
  $source = $('#entity_source')
  $target = $('#entity_target')
  $scope.explain = ->
    q = $scope.query
    if(q.source == undefined or q.source.length == 0 )
      show_input_hint($source, 'Please give me the source entity!')
      return
    if(q.target == undefined or q.target.length == 0 )
      show_input_hint($target, 'Please give me the target entity!')
      return
    $scope.goExplain()
  $scope.explore_source = ->
    q = $scope.query
    if(q.source == undefined or q.source.length == 0 )
      show_input_hint($source, 'Please give me the source entity!')
      return
    $scope.goExplore('source')
  $scope.explore_target = ->
    q = $scope.query
    if(q.target == undefined or q.target.length == 0 )
      show_input_hint($target, 'Please give me the target entity!')
      return
    $scope.goExplore('target')
  $scope.showAuthModal = (mode)->
    $scope.$emit('requestModal', 'auth', mode)
]

.controller 'ExplainController', ['$scope', '$location', '$timeout', '$http', ($scope, $location, $timeout, $http)->
  $scope.ui.showNav = true
  params = $location.search()
  source = params['source']
  target = params['target']
  maxLengthStr = params['maxLength']
  maxLength = if maxLengthStr then parseInt(maxLengthStr) else $scope.config.defaultMaxLength
  if !source or source.length == 0 or !target or target.length == 0
    $location.url('/')
    return
  $scope.query.source = source
  if $scope.query.source_name == undefined
    $scope.query.source_name = source.replace(/_/g, ' ')  # just guess its name for display purpose only
  $scope.query.target = target
  if $scope.query.target_name == undefined
    $scope.query.target_name = target.replace(/_/g, ' ')  # just guess its name for display purpose only
  $scope.query.maxLength = maxLength
  $scope.ui.navMode = 'explain'
  $scope.rating_ready = false

  $scope.zoomIn = ->
    if $scope.zoom_level >= $scope.predicate_priority.length - 1
      console.log('Cannot zoom in further')
      return
    $scope.zoom_level += 1
    $scope.update_graph()

  $scope.zoomOut = ->
    if $scope.zoom_level <= 0
      console.log('Cannot zoom out further')
      return
    $scope.zoom_level -= 1
    $scope.update_graph()

  $scope.saveImage = ->
    save_canvas("#{source} - #{target}.png")

  $scope.saveGraphJson = ->
    blob = objToBlob($scope.data, true)
    saveAs(blob, "#{source} - #{target}.json")

  $scope.reverseList = (list)->
    return list

  $scope.clean_label = (label)->
    if label == undefined or label == null
      return label
    if label[0] != '<'  # ns:name, remove ns: part
      ns_end = label.indexOf(':')
      if ns_end > 0
        label = label.substr(ns_end + 1)
    label = label.replace(/_/g, ' ')
    return label

  $scope.clean_compound_label = (label)->
    return label.split('/').map((s)-> $scope.clean_label(s)).join('/')

  highlight_interval = 0
  highlight_end_timeout = 0
  $scope.highlight_edge = (node, edge_info)->
    from = cy.getElementById(node)
    to = cy.getElementById(edge_info.node)
    if not edge_info.is_outgoing
      tmp = from
      from = to
      to = tmp
    edge = null
    for e in from.edgesTo(to)
      if e.data('predicate') == edge_info.predicate
        edge = e
        break
    items = from.union(to).union(edge)
    cy.fit(items, cy_default_padding)
    clearTimeout(highlight_end_timeout)
    clearInterval(highlight_interval)
    items.addClass('highlighted')
    highlight_interval = setInterval ->
      items.toggleClass('highlighted')
    , 300
    highlight_end_timeout = setTimeout ->
      clearInterval(highlight_interval)
      items.removeClass('highlighted')
    , 1100

  $scope.highlightInnerNode = (compoundNode, innerNode, reverse)->
    compound = cy.getElementById(compoundNode)
    highlight_items = []
    for edge_info in $scope.adj_lists[innerNode]
      other = edge_info.node
      otherGroupId = $scope.view_model.nodes_to_group[other]
      from = compound
      to = cy.getElementById(otherGroupId)
      highlight_items.push(to)
      if not edge_info.is_outgoing
        tmp = from
        from = to
        to = tmp
      edge = null
      for e in from.edgesTo(to)
        if e.data('predicate') == edge_info.predicate
          edge = e
          break
      if edge == null
        console.warn(edge_info)
      else
        highlight_items.push(edge)
    for item in highlight_items
      if !reverse
        item.addClass('highlighted')
      else
        item.removeClass('highlighted')

  $scope.reset_viewport = ->
    cy.fit(undefined, cy_default_padding)

  $scope.hide_controller = (hide)->
    if hide
      if not $controller_wrapper.hasClass('collapsed')
        graph_width = $graph_wrapper.width()
        $controller_wrapper.addClass('collapsed')
        $graph_wrapper.addClass('expanded')
        width_diff = $graph_wrapper.width() - graph_width
        cy.panBy
          x: width_diff
        cy.resize()
        cy.resize()  # new piece of shit
    else
      if $controller_wrapper.hasClass('collapsed')
        graph_width = $graph_wrapper.width()
        $controller_wrapper.removeClass('collapsed')
        $graph_wrapper.removeClass('expanded')
        width_diff = $graph_wrapper.width() - graph_width + 15  # why add 15 ? damn it
        cy.panBy
          x: width_diff
        cy.resize()
        cy.resize()  # new piece of shit
    return

  $scope.layouts = cy_layouts
  for layout in cy_layouts
    if layout.name == 'dagre'  # default layout name
      $scope.layout = layout
      break
  $scope.update_layout = -> cy.layout($scope.layout)

  $scope.$watch 'auth.user', (newVal)->
    if !!newVal and !!$scope.data
      load_user_ratings()

  $scope.$watch 'auto_mode', (newVal, oldVal)->
    if oldVal == false and newVal == true
      need_update = false
      for item,i in $scope.predicate_priority
        if i <= $scope.zoom_level
          if not item.active
            need_update = true
            break
        else
          if item.active
            need_update = true
            break
      if need_update
        $scope.update_graph()

  $('.btn-show-rankings').on 'click', ->
    body = $("html, body")
    body.stop().animate
      scrollTop: $('.graph').height()
    , '500', 'swing'
  cy = setup_cy($('.graph-explain'))
  $nodeDetailsTab = $('a[href="#node-details"]')
  cy.on 'tap', 'node', (event)->
    $scope.$apply ->
      $scope.focusedItem = event.cyTarget
    $scope.hide_controller(false)
    $nodeDetailsTab.tab('show')
  $('[data-toggle="tooltip"]').tooltip()

  $scope.open_explore_window = (target)->
    if target.isEdge()
      id = target.data('predicate')
    else
      id = target.data('id')
    if id[0] != '<'
      console.warn 'Only DBpedia resource nodes are supported now!'
      return
    id = id.substr(1, id.length - 2)
    id = encodeURIComponent(id)
    #$scope.$apply ->
    #  $location.url("/explore?node=#{name}")
    window.open("#/explore?node=#{id}")
    return

  $('a[data-toggle="tab"]').on 'click', (e)->
    e.preventDefault()
    $(@).tab('show')

  $navbar = $('.app-navbar')
  $controller_wrapper = $('.graph-controller-wrapper')
  $graph_wrapper = $('.graph-wrapper')
  update_graph_controller_position = ->
    $controller_wrapper.css 'padding-top', $navbar.height()
  $(window).on 'resize', update_graph_controller_position
  setTimeout update_graph_controller_position, 500

  load_user_ratings = ->
    if $scope.data.rankings == undefined
      return
    $scope.rating_ready = false
    $http.get("api/ratings?source=#{encodeURIComponent(source)}&target=#{encodeURIComponent(target)}").then (response)->
      pathRank = $scope.data.rankings.pathInfoRanking
      for record in pathRank
        record.rating = undefined
        record.rating_id = undefined
      for rating in response.data
        rating_path = rating.path
        for record in pathRank
          record_path = record.object.triples
          if rating_path.length != record_path.length
            continue
          mismatch = false
          for rating_triple, i in rating_path
            record_triple = record_path[i]
            if rating_triple.s != record_triple.s or rating_triple.p != record_triple.p or rating_triple.o != record_triple.o
              mismatch = true
              break
          if !mismatch
            record.rating = rating.rating
            record.rating_id = rating.id
      $scope.rating_ready = true
    , (response)->
      alert(format_response_error(response))

  handle_data = (data)->
    $scope.data = data
    if !!$scope.auth.user
      load_user_ratings()
    $scope.source = data.source
    $scope.target = data.target
    $scope.nodes = core.get_node_set(data.triples)
    $scope.type_dict = core.get_clean_type_dict(data.types, $scope.nodes)
    $scope.adj_lists = core.triples_to_adj_lists(data.triples)
    $scope.predicate_priority = core.get_predicate_priority(data.triples)
    $scope.zoom_level = 0
    $scope.type_info = core.get_type_info($scope.type_dict)
    $scope.type_hierarchy_view = core.compute_type_hierarchy_view($scope.type_info)
    $scope.auto_mode = true

    nodes_count = 0
    for k of $scope.nodes
      nodes_count += 1
    console.log('[Raw Nodes]', nodes_count, '[Raw Edges]', $scope.data.triples.length)
    $scope.update_graph()

  $scope.update_graph = ->
    $scope.focusedItem = null
    time_start = Date.now()
    if $scope.auto_mode  # apply auto predicate config based on current zoom level
      for item, i in $scope.predicate_priority
        item.active = i <= $scope.zoom_level
    $scope.init_partition = core.get_init_partition($scope.nodes, $scope.source, $scope.target, $scope.type_dict, $scope.type_info)
    partition = $scope.init_partition
    for item in $scope.predicate_priority
      if item.active
        partition = simulation.get_coarsest_partition($scope.adj_lists, $scope.nodes, partition, item.predicate)
    $scope.partition = partition
    $scope.view_model = core.compute_view_model($scope.adj_lists, $scope.type_dict, $scope.partition, $scope.view_model)
    update_graph_view()
    time_elapsed = Date.now() - time_start
    console.log('[Nodes]', cy.nodes().length, '[Edges]', cy.edges().length ,'[Time]', time_elapsed)

  update_graph_view = ->
    for node in $scope.view_model.nodes_removed
      old_node = cy.getElementById(node.id)
      cy.remove old_node
    for node in $scope.view_model.nodes_added
      cy.add
        data:
          id: node.id
          name: $scope.clean_compound_label(node.label)
          nodes: node.nodes
          is_compound: node.nodes.length > 1
    for edge in $scope.view_model.edges_added
      cy.add
        data:
          name: $scope.clean_label(edge.predicate)
          predicate: edge.predicate
          source: edge.source
          target: edge.target
    cy.$("[id='#{$scope.source}']").addClass('source')
    cy.$("[id='#{$scope.target}']").addClass('target')
    for predicate in $scope.predicate_priority
      if predicate.active
        cy.edges("[predicate='#{predicate.predicate}']").addClass('enabled')
      else
        cy.edges("[predicate='#{predicate.predicate}']").removeClass('enabled')
    $scope.update_layout()

  data = undefined
  useLocalStorage = false # typeof(Storage) != "undefined"
  if useLocalStorage
    last_explain = localStorage.getItem('last_explain')
    if !!last_explain
      last_explain = JSON.parse(last_explain)
      if last_explain.source == source and last_explain.target == target
        data = last_explain.result
  if data == undefined
    $scope.state.querying_explain = true
    $http.get("api/explain?source=#{source}&target=#{target}&maxLength=#{maxLength}").then (response)->
      $scope.state.querying_explain = false
      handle_data(response.data)
      if useLocalStorage
        localStorage.setItem 'last_explain', JSON.stringify
          source: source
          target: target
          result: response.data
      $timeout ->
        cy.resize()
      , 0
    , (response)->
      $scope.state.querying_explain = false
      alert(format_response_error(response))
  else
    handle_data(data)
]

.controller 'ExploreController', ['$scope', '$location', '$http', '$sce', ($scope, $location, $http, $sce)->
  $scope.ui.showNav = true
  params = $location.search()
  node = params['node']
  if !node
    return
  from = params['from']
  if !from or from == 'source'
    $scope.query.source = node
    if $scope.query.source_name == undefined
      $scope.query.source_name = node.replace(/_/g, ' ')  # just guess its name for display purpose only
    $scope.ui.navMode = 'explore_source'
  else
    $scope.query.target = node
    if $scope.query.target_name == undefined
      $scope.query.target_name = node.replace(/_/g, ' ')  # just guess its name for display purpose only
    $scope.ui.navMode = 'explore_target'

  if node.startsWith("http://") or node.startsWith("https://")
    url = node
  else
    url = 'http://dbpedia.org/resource/' + node
  $scope.url = $sce.trustAsResourceUrl(url)
]
