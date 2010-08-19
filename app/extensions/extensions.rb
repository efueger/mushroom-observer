# Load all our class extensions. *NOTE*: These will not auto-load because the
# class (presumably) already exist.  This is required by ApplicationController.
# Rake tasks, depending on their environment, might need to require this
# explicitly, too.  (Although, I believe ApplicationController is always
# loaded, no matter what you need(?)...) 

require 'array_extensions'
require 'enumerable_extensions'
require 'fixnum_extensions'
require 'form_builder_extensions'
require 'hash_extensions'
require 'object_extensions'
require 'string_extensions'
require 'symbol_extensions'
require 'time_extensions'