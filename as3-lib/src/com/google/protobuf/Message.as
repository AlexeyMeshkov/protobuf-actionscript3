// Protocol Buffers - Google's data interchange format
// Copyright 2008 Google Inc.
// http://code.google.com/p/protobuf/
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package com.google.protobuf
{
	import flash.utils.ByteArray;
	import flash.utils.getDefinitionByName;
	import flash.utils.getQualifiedClassName;
	import flash.utils.IDataInput;
	import flash.utils.IDataOutput;
	
	/**
	 * This would be better if it were abstract, then we could create
	 * an interface and move fieldDescriptors into the actual message
	 * implementation and make it static (more efficient)
	 *
	 * @author Robert Blackwood
	 */
	public class Message {
	
	  // -----------------------------------------------------------------------------
	  private static const EXTENDED_FIELDNAME_CLASSNAME : String = "messageClassName";
	  /// { message classname{ descriptorFieldName = Descriptor } }
	  private static const m_cacheFieldNameDescriptor : Object = { };
	  /// { message classname{ descriptorFieldNumber = Descriptor } }
	  private static const m_cacheFieldNumberDescriptor : Object = { };
	  /// { message classname = Class }
	  private static const m_cacheMessageClassByClassName : Object = { };
	  // -----------------------------------------------------------------------------
	  public static function ExtractMessageClassName( _message : Message ) : String    {
	    if ( _message == null )
	    {
	      return "null";
	    }
	    return _message.hasOwnProperty( EXTENDED_FIELDNAME_CLASSNAME ) ? _message[ EXTENDED_FIELDNAME_CLASSNAME ] : getQualifiedClassName( _message );
	  }
	  // -----------------------------------------------------------------------------
	  public static function CreateMessageByClassName( _messageClassName : String ) : Message    {
	    var classRef : Class = ReflectClassByMessageClassName( _messageClassName );
	    return new classRef();
	  }
	  // -----------------------------------------------------------------------------
	  public static function ReflectClassByMessageClassName( _messageClassName : String ) : Class    {
	    var classRef : Class = null;
	    if ( _messageClassName )
	    {
	      classRef = m_cacheMessageClassByClassName[ _messageClassName ];
	      if ( classRef == null )
	      {
	        try
	        {
	          classRef = getDefinitionByName( _messageClassName ) as Class;
	          m_cacheMessageClassByClassName[ _messageClassName ] = classRef;
	        }
	        catch ( _error : Error )
	        {
	          classRef = null;
	          throw new Error( " Message -> CreateInstanseMessageByClassNameOrNull : Unknown class " + _messageClassName );
	        }
	      }
	    }
	    return classRef;
	  }
	  // -----------------------------------------------------------------------------
	  // -----------------------------------------------------------------------------

	  private var receivedFields : Object = null;
	  private var descriptorsByFieldName : Object = null;
	  private var descriptorsByFieldNumber : Object = null;

	  protected var fields_are_registered : Boolean = false;

	  //Intialize our field descriptors
	  public function Message() {
	    const className : String = this[ EXTENDED_FIELDNAME_CLASSNAME ];
	    if ( className == null ) {
	      descriptorsByFieldName = { };
	      descriptorsByFieldNumber = { };
	    }
	    else {
	      descriptorsByFieldName = m_cacheFieldNameDescriptor[ className ];
	      descriptorsByFieldNumber = m_cacheFieldNumberDescriptor[ className ];
	      if ( descriptorsByFieldName ) {
	        fields_are_registered = true;
	      }
	      else {
	        descriptorsByFieldName = { };
	        descriptorsByFieldNumber = { };
	        m_cacheFieldNameDescriptor[className] = descriptorsByFieldName;
	        m_cacheFieldNumberDescriptor[className] = descriptorsByFieldNumber;
	      }
	    }
	  }
	
	  public final function writeToDataOutput(output:IDataOutput):void {
	
			const codedOutput : CodedOutputStream = CodedOutputStream.newInstance( output );
			for each (var desc:Descriptor in descriptorsByFieldName) 
			{
		
        	//Don't write it if it is null
			const thisField  : * = this[ desc.fieldName ];
			const fieldNumber  : int = desc.fieldNumber;
			if (thisField == null)
			{
				if( desc.isRequired )
					trace("Missing required field " + desc.fieldName);
			}
			else
			{
				//We have an array, write it out
				const fieldIsEnumerated : Boolean = desc.isRepeated
          && (
            // there are vector specializations for int, uint and Number and check for Vector.<*> doesn't work for them
            thisField is Vector.<int>
            || thisField is Vector.<uint>
            || thisField is Vector.<Number>
            || thisField is Vector.<*>
            || thisField is Array
          );
				if (fieldIsEnumerated)
				{
					for each( var elem:* in thisField )
					{
						//If its a message, recurse this function, else just write out the primative
						if (desc.isMessage)
						{
							//write out the size first
//							codedOutput.writeRawVarint32(elem.getSerializedSize())
//							elem.writeToDataOutput(codedOutput);
							codedOutput.writeMessage(fieldNumber, elem);
						}
						else //primative
							codedOutput.writeField( fieldNumber , elem , desc );
					}
				}
				else
				{
					//Message/primative thats not repeated
					if (desc.isMessage)
					{
						if ( thisField is Message )
							codedOutput.writeMessage(fieldNumber , thisField);
					}
					else //primative
						codedOutput.writeField( fieldNumber , thisField , desc );
				}
			}
        }
      }

	
	  /**
	  * Wrapper for readFromCodedStream, take something coforming to
	  * the IDataInput interface and construct a coded stream from it
	  */
	  public final function readFromDataOutput( input : IDataInput ) : void
	  {
	  	receivedFields = {}; // inline function  clearReceivedFields();

	  	var codedInput : CodedInputStream = new CodedInputStream( input ); // inline function  CodedInputStream.newInstance( input );
		//Get the first tag
	  	var tag:int = codedInput.readTag();
	
	  	//Loop thru everything we get
	  	var fieldNum : int;
	  	var desc : Descriptor;
	  	var item : *; //The item can be any type
	  	var desc_fieldName : String;
	  	var size : int;
	  	var bytes : ByteArray;
	  	const tagTypeBits:int = WireFormat.TAG_TYPE_BITS;
	  	while (tag != 0)
	  	{
	  		//Grab our info from the tag
	  		fieldNum = tag >>> tagTypeBits; // inline function  WireFormat.getTagFieldNumber( tag );
	  		desc = getDescriptorByFieldNumber(fieldNum);

	  		if (desc != null)
	  		{
	  			desc_fieldName = desc.fieldName;
	  			receivedFields[ desc_fieldName ] = 1; // inline function  setReceivedField(desc_fieldName);
	
	  			//If we have a message, recurse this function to read it in
	  			if (desc.isMessage)
	  			{
	  				item = CreateMessageByClassName( desc.messageClass );
	  				//Read whole message to ByteArray (not the best, too slow but easy)
	  				size = codedInput.readRawVarint32();
	  				bytes = codedInput.readRawBytes( size );
	  				//fix bug 1 protobuf-actionscript3
	  				bytes.position = 0;
	  				item.readFromDataOutput( bytes );
	  			}
	  			//Just a primative type, read it in
	  			else
	  				item = codedInput.readPrimitiveField(desc.type);
	
	  			//We have an array, push item to the array
	  			if (desc.isRepeated)
          {
	  				//Concatenation automatically happens if duplicate
	  				// for best performance
	  				// info : http://blog.derraab.com/2012/05/06/actionscript-performance-test-for-array-object-vector-literals-and-array-push-vector-push-methods/
	  				this[ desc_fieldName ][this[ desc_fieldName ].length] = item; // = this[ desc_fieldName ].push( item );
	  			}
				  else
          {
		  			this[desc_fieldName] = item; //just set it (official pb requires merging here, in the case of duplicates)
          }
	  		}
	  		else
	  			codedInput.skipField(tag); //Throw it away, we don't have that version
	
	  		//Read the next tag in stream
	  		tag = codedInput.readTag();
	  	}
	  }
	
	  /**
	  * When writing a message field, it is length delimited, therefore
	  * we must know it's exact size before we write it, this function
	  * uses the output stream to determine the correct size
	  */
	  public final function getSerializedSize():int {
	
	  	var size:int = 0;
	
	    for each (var desc:Descriptor in descriptorsByFieldName)
	    {
	    	//Ignore null fields.. cause we won't write them!
	    	if (this[desc.fieldName] != null)
				size += CodedOutputStream.computeFieldSize( desc.fieldNumber, this[desc.fieldName]);
		}
		
		return size;
	  }
	
	  /**
	  * All subclasses must register the fields they want visible to
	  * protocol buffers. The protoc executable will take care of
	  * registering fields for you.
	  */
	  protected final function registerField(field:String, messageClass:String, type:int, label:int, fieldNumber:int):void {

		//register descriptors only once
			if (descriptorsByFieldName[field]) {
				return;
			}
			const descriptor:Descriptor = new Descriptor(field,messageClass,type,label,fieldNumber);
			descriptorsByFieldName[ field ] = descriptor
			descriptorsByFieldNumber[ fieldNumber ] = descriptor;
	  }
	
	  /**
	  * Convenience method for getting a descriptor by field number
	  */
	  private final function getDescriptorByFieldNumber(fieldNum:int):Descriptor {
	    return descriptorsByFieldNumber[fieldNum];
	  }
	
	  /**
	  * fieldDescriptors is an associative array that uses the field's
	  * name as an index for retrieving a descriptor. This function
	  * is just a more descriptive way of indexing the array.
	  */
	  public final function getDescriptor(field:String):Descriptor {
		 	return descriptorsByFieldName[field];
	  }

    /**
     * Iterates over all descriptors in protobuf and calls function f with one parameter - descriptor
     */
	  public final function iterateDescriptors(f:Function):void {
	  	for each ( var desc:Descriptor in descriptorsByFieldName ) {
        f( desc );
      }
    }

    /**
     * Checks if field was set in protobuf
     */
    public final function isFieldSet(field:String):Boolean {
      return ( receivedFields != null ) && receivedFields.hasOwnProperty(field);
    }

    public final function setReceivedField(field:String):void {
      receivedFields[field] = 1;
    }
	
    public final function clearReceivedFields():void {
      receivedFields = {};
    }
	  // =================================================================
	}
}
