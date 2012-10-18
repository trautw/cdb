/*
 * File: Canvas.js
 * 
 * Author: Nicolas Garcia Belmonte
 * 
 * Copyright: Copyright 2008-2009 by Nicolas Garcia Belmonte.
 * 
 * License: BSD License
 * 
 * Homepage: <http://thejit.org>
 * 
 * Version: 1.0.8a
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the organization nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY Nicolas Garcia Belmonte ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL Nicolas Garcia Belmonte BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 */


/*
   Class: Canvas

   A multi-purpose Canvas object decorator.
*/
var Canvas = (function () {
  var ctx, bkctx, mainContainer, labelContainer, canvas, bkcanvas;
  var config = {
    'injectInto': 'id',
    
    'width':200,
    'height':200,
    
    'backgroundColor':'#333333',
    
    'styles': {
      'fillStyle':'#000000',
      'strokeStyle':'#000000'
    },
    
    'backgroundCanvas': false
  };
  
  function hasCanvas() {
    hasCanvas.t = hasCanvas.t || typeof(HTMLCanvasElement);
    return "function" == hasCanvas.t || "object" == hasCanvas.t;
  };
  
  function create(tag, prop, styles) {
    var elem = document.createElement(tag);
    (function(obj, prop) {
      if(prop) for (var p in prop) obj[p] = prop[p];
      return arguments.callee;
    })(elem, prop)(elem.style, styles);
     //feature check
     if(tag == "canvas" && !hasCanvas() && G_vmlCanvasManager) {
      elem = G_vmlCanvasManager.initElement(
        document.body.appendChild(elem));
     }
      
    return elem;
  };
  
  function get(id) {
    return document.getElementById(id);
  };
  
  function translateToCenter(canvas, ctx, w, h) {
    var width = w? (w - canvas.width) : canvas.width;
    var height = h? (h - canvas.height) : canvas.height;
    ctx.translate(width / 2, height / 2);
  };
  
  /*
     Constructor: Canvas
  
     Canvas constructor.
  
     Parameters:
  
        id - The canvas tag id.
        opt - configuration object, possible parameters are:
        - *injectInto* id for the container of the canvas.
        Canvas object will be appended to the object specified by this id.
        - *width* canvas width, default's 200
        - *height* canvas height, default's 200
        - *backgroundColor* used for background color when clipping in IE
        - *styles* an object containing canvas style properties. See <https://developer.mozilla.org/en/Canvas_tutorial/Applying_styles_and_colors>
      - *backgroundCanvas* an object containing configuration properties for a background canvas.
      
      A possible configuration object could be defined as:
      (start code)
      var config = {
        'injectInto': 'id',
        
        'width':200,
        'height':200,
        
        'backgroundColor':'#333333',
        
        'styles': {
          'fillStyle':'#000000',
          'strokeStyle':'#000000'
        },
        
        'backgroundCanvas': false
      };
      (end code)
      
      More information in <http://blog.thejit.org>.

     Returns:
  
        A new Canvas instance.
  */
  return function(id, opt) {
    if(arguments.length < 1) throw "Arguments missing";
    var idLabel = id + "-label", idCanvas = id + "-canvas", idBCanvas = id + "-bkcanvas";
    opt = $_.merge(config, opt || {});
    //create elements
    var dim = { 'width': opt.width, 'height': opt.height };
    mainContainer = create("div", { 'id': id }, $_.merge(dim, { 'position': 'relative' }));
    labelContainer = create("div", { 'id': idLabel }, { 
      'overflow': 'visible',
      'position': 'absolute',
      'top': 0,
      'left': 0,
      'width': dim.width + 'px',
      'height': 0
    });
    var dimPos = {
      'position': 'absolute',
      'top': 0,
      'left': 0,
      'width': dim.width + 'px',
      'height': dim.height + 'px'
    };
    canvas = create("canvas", $_.merge({ 'id': idCanvas }, dim), dimPos);
    var bc = opt.backgroundCanvas;
    if(bc) {
      bkcanvas = create("canvas", $_.merge({ 'id': idBCanvas }, dim), dimPos);
      //append elements
      mainContainer.appendChild(bkcanvas);
    }
    mainContainer.appendChild(canvas);
    mainContainer.appendChild(labelContainer);
    get(opt.injectInto).appendChild(mainContainer);
    
    //create contexts
    ctx = canvas.getContext('2d');
    translateToCenter(canvas, ctx);
    var st = opt.styles;
    for(var s in st) ctx[s] = st[s];
    if(bc) {
      bkctx = bkcanvas.getContext('2d');
      var st = bc.styles;
      for(var s in st) bkctx[s] = st[s];
      translateToCenter(bkcanvas, bkctx);
      bc.impl.init(bkcanvas, bkctx);
      bc.impl.plot(bkcanvas, bkctx);
    }
    //create methods
    return {
      'id': id,
      /*
         Method: getCtx
      
         Returns:
      
            Main canvas context.
      */
      getCtx: function() {
        return ctx;
      },

      /*
         Method: getElement
      
         Returns:
      
            DOM canvas wrapper generated. More information
            about this can be found in the post <http://blog.thejit.org>
      */
      getElement: function() {
        return mainContainer;
      },
      
      /*
         Method: resize
      
         Resizes the canvas.
      
         Parameters:
      
            width - New canvas width.
            height - New canvas height.
      
      */
      resize: function(width, height) {
        (function(canvas, ctx) {
          translateToCenter(canvas, ctx, width, height);
          canvas.width = width;
          canvas.height = height;
          return arguments.callee;
        })(canvas, ctx)(bkcanvas, bkctx);
      },
      
      /*
         Method: getSize
      
         Returns canvas dimensions.
      
         Returns:
      
            An object with _width_ and _height_ properties.
      */
      getSize: function() {
        return { 'width': canvas.width, 'height': canvas.height };
      },
      
      /*
         Method: path
         
        Performs a _beginPath_ executes _action_ doing then a _type_ ('fill' or 'stroke') and closing the path with closePath.
      */
      path: function(type, action) {
        ctx.beginPath();
        action(ctx);
        ctx[type]();
        ctx.closePath();
      },
      
      /*
         Method: clear
      
         Clears the canvas object.
      */    
      clear: function () {
        var size = this.getSize();
        ctx.clearRect(-size.width / 2, -size.height / 2, size.width, size.height);
      },
      
      /*
         Method: clearReactangle
      
         Same as <clear> but only clears a section of the canvas.
         
         Parameters:
         
          top - An integer specifying the top of the rectangle.
          right -  An integer specifying the right of the rectangle.
          bottom - An integer specifying the bottom of the rectangle.
          left - An integer specifying the left of the rectangle.
      */    
      clearRectangle: function (top, right, bottom, left) {
        //if using excanvas
        if(!hasCanvas()) {
          var f0 = ctx.fillStyle;
          ctx.fillStyle = opt.backgroundColor;
          ctx.fillRect(left, top, right - left, bottom - top);
          ctx.fillStyle = f0;
        } else {
          //TODO absolutely arbitraty offsets!
          ctx.clearRect(left, top -2, right - left +2, Math.abs(bottom - top) +5);
        }
      },
      
      /*
         Method: makeRect
      
         Draws a rectangle in canvas.
      
         Parameters:
      
            mode - A String sepecifying if mode is "fill" or "stroke".
            pos - A set of two coordinates specifying top left and bottom right corners of the rectangle.
      */
      makeRect: function(pos, mode) {
        if(mode == "fill" || mode == "stroke") {
          ctx[mode + "Rect"](pos.x1, pos.y1, pos.x2, pos.y2);
        } else throw "parameter not recognized " + mode;
      }
      
    };
  };
  
})();
