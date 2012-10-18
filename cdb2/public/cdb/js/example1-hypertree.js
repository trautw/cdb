// See http://thejit.org/static/v20/Docs/files/Core/Core-js.html

var Log = {
  elem: false,
  write: function(text) {
    if(!this.elem) this.elem = $('log');
    this.elem.set('html', text);
  },
  
  writeDelay: function(text) {
    if(!this.elem) this.elem = $('log');
    var that = this;
    (function () { that.elem.set('html', text); }).delay(2000);
    
  }
};

Config.drawMainCircle = false;

var Layout = {

  init: function() {
    var size = Window.getSize();
    var header = $('header'), left = $('left'), infovisContainer = $('infovis');
    var headerOffset = header.getSize().y, leftOffset = left.getSize().x;

    var newStyles = {
      'height': Math.floor((size.y - headerOffset)),
      'width' : Math.floor((size.x - leftOffset))
    };

    infovisContainer.setProperties(newStyles);
    infovisContainer.setStyles(newStyles);
    infovisContainer.setStyles({
      'position':'absolute',
      'top': headerOffset + 'px',
      'left': leftOffset + 'px'
    });
    left.setStyle('height', newStyles.height);
    var totalHeight = 0;
    $$('.toggler').each(function(elem) {
      totalHeight += elem.offsetHeight;
    });
    var h = newStyles.height - totalHeight;
    $$('.content').each(function(elem) {
      elem.setStyle('height', h - 24);
    });
    $$('#navigation ul li a').each(function (elem) {
      elem.addEvent('click', function() {
        PageController.makeRequestAndPlot(elem.innerHTML.trim());
      });
    });
    this.initAccordion(h);
  },
  
  initAccordion: function(height) {
    new Accordion($$('.toggler'), $$('.element'), {
      display: 0,
      fixedHeight:height,
      onActive: function(toggler, element) {
        toggler.morph({
          'background-color': '#7389AE',
          'color':'#fff'  
        });
      },
      onBackground: function(toggler, element) {
        toggler.morph({
          'background-color': '#555',
          'color':'#d5d5d5' 
        });
      }
    });
  }
};

function init() {
  var infovis = $('infovis');
  var w = infovis.offsetWidth, h = infovis.offsetHeight;
  //Create a new canvas instance.
  var canvas = new Canvas('mycanvas', {
    'injectInto':'infovis',
    'width': w,
    'height':h,
    'styles': {
        'fillStyle': '#ddd',
        'strokeStyle': '#ddd'
    }
  });
  var ht = new Hypertree(canvas,  {
    clickedNodeId: "",
    clickedNodeName: "",
    childResponsesRemaining: "",

    onBeforeCompute: function(node) {
      Log.write("centering...");
    },
    
    preprocessTree: function(json) {
      var ch = json.children;
      var getNode = function(nodeName) {
        for(var i=0; i<ch.length; i++) {
          if(ch[i].name == nodeName) return ch[i];
        }
        return false;
      };
      json.id = this.clickedNodeId;
      GraphUtil.eachAdjacency(ht.graph.getNode(this.clickedNodeId), function(elem) {
        var nodeTo = elem.nodeTo, jsonNode = getNode(nodeTo.name);
        if(jsonNode) jsonNode.id = nodeTo.id;
      });
    },
    
    getDescription: function() {
      var that = this;
      Log.write("getting description...");
    new Request.JSON({
      // 'url':'./musictrails-description/' + encodeURIComponent(that.clickedNodeName) + '/index.js',
      'url':'./musictrails-description/' + that.clickedNodeId + '/index.js',
      onFailure: function() {
        Log.write("Error getting description!");
        Log.writeDelay("done");
      },
      
      onSuccess: function(json) {
        $('details').set('html', "<b>"+ json.name + "</b><br /><br /><img src=\"" + json.img + "\" />" + json.bio);
        Log.write("done");
      }
    }).get();
    },

    registerChildResponse: function(that, json, id) {
      // console.debug("Got Childresponse "+this.childResponsesRemaining);
      this.childResponsesRemaining--;
      if (this.childResponsesRemaining == 0) {

          that.preprocessTree(json);

          GraphOp.sum(ht, json, {
            id: id,
            type: 'fade:con',
            duration: 1000,
            hideLabels: false,
            onComplete: function() {

              var subNodes = GraphUtil.getSubnodes(ht.graph,id,3);

              var subNodeIds = new Array();
              subNodes.each( function (aNode) {
                subNodeIds.push(aNode.id);
              });

              Log.write("removing...");
              // console.debug("subNodeIds = "+subNodeIds);
              GraphOp.removeNode(ht, subNodeIds, {
                type: 'fade:seq',
                duration: 1000,
                hideLabels: false,
                transition: Trans.Quart.easeOut,
                onComplete: function() {
                  that.getDescription();
                },
                onAfterCompute: $lambda(),
                onBeforeCompute: $lambda()
              });
            },

            onAfterCompute: $lambda(),
            onBeforeCompute: $lambda()
          });

      }
    },
 
    requestGraph: function() {
      var that = this, id = this.clickedNodeId;
      // console.debug("Got mouseclick");

      // Go to page?
      var clickedNode = ht.graph.getNode(this.clickedNodeId)
      if ((typeof clickedNode.data!='undefined') && (typeof clickedNode.data.siteURL!='undefined')){
        console.debug("Going to "+clickedNode.data.siteURL);
        window.open(clickedNode.data.siteURL,'_blank');
      } else {

      Log.write("requesting info...");
      var jsonRequest = new Request.JSON({
        // 'url': './musictrails/' + encodeURIComponent(that.clickedNodeName) + '/index.js',
        'url': '/' + that.clickedNodeId + '/newshowall.json',
        onSuccess: function(json) {
          Log.write("morphing...");

          that.childResponsesRemaining = json.uses.length;

          json.uses.each( function(child) {
            // console.debug("Processing child "+child.name);
            var jsonRequest = new Request.JSON({
              // 'url': './musictrails/' + encodeURIComponent(child.name) + '/index.js',
              'url': '/' + child.id + '/newshowall.json',
              onFailure: function(text, error) {
                Log.write("sorry, the request failed");
                Log.writeDelay("done");
                that.registerChildResponse(that, json, id);
              },
              onSuccess: function(responseJSON, responseText) {
                console.debug("Got "+responseText);
                json.children.each( function(child) {
                  if (child.id == responseJSON.id) {
                    console.debug("Subchilds einhaengen");
                    child.children = responseJSON.children;
                    child.children.done = true;
                  }
                });
                json.children[json.children.length] = responseJSON;
				// json.children[json.children.length] =  { "children":[ ], "id":"Haspa90_41312919950.94", "name":"Haspa90" };
				console.debug("Now we have responseJSON.id "+responseJSON.id);
				console.debug("Now we have "+json.children[responseJSON.id]);
                that.registerChildResponse(that, json, id);
              }
            }).get();
          });

          // json.children[json.children.length] =  { "children":[ ], "id":"Haspa90_41312919950.94", "name":"Haspa90" };
        },
        onFailure: function() {
          Log.write("sorry, the request failed");
          Log.writeDelay("done");
        }
      }).get();
      }
    },
    
  //Add a controller to assign the node's name to the created label.  
    onCreateLabel: function(domElement, node) {
      var d = $(domElement);
      d.setOpacity(0.8).set('html', node.name).addEvents({
        'mouseenter': function() {
          d.setOpacity(1);
        },
        
        'mouseleave': function() {
          d.setOpacity(0.8);
        },
        
        'click': function() {
        if(Log.elem.innerHTML == "done") ht.move(node.pos.toComplex());
        }
      });
    },
    
    //Take off previous width and height styles and
    //add half of the *actual* label width to the left position
    // That will center your label (do the math man). 
    onPlaceLabel: function(domElement, node) {
     domElement.style.display = "none";
     // if(node._depth <= 1) {
     if(node._depth <= 2) {
      if(typeof node.data!='undefined'){
        if(typeof node.data.labelHTML!='undefined'){
          domElement.innerHTML = node.data.labelHTML;
        } else {
          domElement.innerHTML = node.name;
        };
      } else {
        domElement.innerHTML = node.name;
      }

      domElement.style.display = "";
      var left = parseInt(domElement.style.left);
      domElement.style.width = '';
      domElement.style.height = '';
      var w = domElement.offsetWidth;
      domElement.style.left = (left - w /2) + 'px';
    } 
  },
  
  onAfterCompute: function() {
    Log.write("done");
    var node = GraphUtil.getClosestNodeToOrigin(ht.graph, "pos");
    this.clickedNodeId = node.id;
    this.clickedNodeName = node.name;
    History.add(this.clickedNodeName);
    this.requestGraph();
  }
  });
  
  PageController.ht = ht;
}

var PageController = {
  ht: null,
  busy:false,
    
  makeRequestAndPlot: function(name) {
    if(this.busy) return;
    this.busy = true;
    var that = this;
    if(this.ht.busy == true) return;
    Animation.timer = clearInterval(Animation.timer);
    this.ht.busy = false;
    History.clear();
    // name = encodeURIComponent(name);
    var ht = this.ht;
    ht.controller.clickedNodeId = "";
    ht.controller.clickedNodeName = "";
    Log.write("wait for it... it might take a while");
    new Request.JSON({
        // 'url':'./musictrails/'+ name +'/index.js',
        'url':'/'+ name +'/newshowall.json',
        onSuccess: function(json) {
         GraphPlot.labelsHidden = false;
         GraphPlot.labels = {};
         $('mycanvas-label').empty().setStyle('display', '');        
          //load weighted graph.
         ht.loadTreeFromJSON(json);
          //compute positions
          ht.compute();
          //make first plot
          ht.plot();
          Log.write("done");
          ht.controller.clickedNodeName = name;
          that.busy = false;
          that.requestForDetails(name);
        },
        
        onFailure: function() {
          Log.write("failed!");
        Log.writeDelay("done");
        }
    }).get();
  },
  
  requestForDetails: function(name) {
    Log.write("getting description...");
    new Request.JSON({
      // 'url':'./musictrails-description/' + encodeURIComponent(name) + '/index.js',
      'url':'./musictrails-description/' + name + '/index.js',
      onFailure: function() {
        Log.write("Error getting description!");
        Log.writeDelay("done");
      },
      
      onSuccess: function(json) {
        $('details').set('html', "<b>"+ json.name + "</b><br /><br /><img src=\"" + json.img + "\" />" + json.bio);
        Log.write("done");
      }
    }).get();
  }
};

var History = {
  h: false,
  getHistory: function() {
    return this.h===false? this.h=$('previous-selected-nodes') : this.h;
  },
  
  clear: function() {
    this.getHistory().empty();
  },
  
  add: function(name) {
    var li = new Element('li');
    var a = new Element('a', {
      'events': {
        'click': function() {
          PageController.makeRequestAndPlot(name);
        }
      },
      'html': name,
      'href':'#'
    }).inject(li);
    li.inject(this.getHistory(), 'top');
  }
};

window.addEvent('domready', function() {
  Layout.init();
  init();
  // PageController.makeRequestAndPlot('kunde/norisbank');
  PageController.makeRequestAndPlot('person/christoph');
});
