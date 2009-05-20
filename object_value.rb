# simulation of AR object in rhosync rails app but not saved to DB
class ObjectValue 
  attr_accessor   :id
  attr_accessor   :db_operation
  attr_accessor   :source_id
  attr_accessor   :object
  attr_accessor   :attrib
  attr_accessor   :value
  attr_accessor   :pending_id
  attr_accessor   :update_type
  attr_accessor   :user_id
  
  def initialize(source_id, object, attrib, value)
    @source_id = source_id
    @object = object
    @attrib = attrib
    @value = value
    @id = ObjectValue.hash_from_data(@attrib,@object,@update_type,@source_id,@user_id,@value)
    @db_operation = 'insert'
    @update_type = 'query'
  end
  
  def self.hash_from_data(attrib=nil,object=nil,update_type=nil,source_id=nil,user_id=nil,value=nil,random=nil)
    "#{object}#{attrib}#{update_type}#{source_id}#{user_id}#{value}#{random}".hash.to_i
  end
end