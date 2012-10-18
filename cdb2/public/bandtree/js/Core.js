/*
 * File: Core.js
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
   Object: $_

   Provides some common utility functions.
*/
var $_ = {
  empty: function() {},
  
  fn: function(val) { return function() { return val; }; },

  merge: function(){
    var mix = {};
    for (var i = 0, l = arguments.length; i < l; i++){
      var object = arguments[i];
      if (typeof object != 'object') continue;
      for (var key in object){
        var op = object[key], mp = mix[key];
        mix[key] = (mp && typeof op == 'object' && typeof mp == 'object') ? this.merge(mp, op) : this.unlink(op);
      }
    }
    return mix;
  },

  unlink: function (object){
    var unlinked = null;
    if(this.isArray(object)) {
        unlinked = [];
        for (var i = 0, l = object.length; i < l; i++) unlinked[i] = this.unlink(object[i]);
    } else if(this.isObject(object)) {
        unlinked = {};
        for (var p in object) unlinked[p] = this.unlink(object[p]);
    } else return object;

    return unlinked;
  },
  
  isArray: function(obj) {
    return obj && obj.constructor && obj.constructor.toString().match(/array/i);
  },
  
  isString: function(obj) {
    return obj && obj.constructor && obj.constructor.toString().match(/string/i);
  },
  
  isObject: function(obj) {
    return obj && obj.constructor && obj.constructor.toString().match(/object/i);
  }
} ;

