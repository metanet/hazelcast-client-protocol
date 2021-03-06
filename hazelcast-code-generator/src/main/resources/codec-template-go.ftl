// Copyright (c) 2008-2018, Hazelcast, Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package protocol

<#global isImported = false>
import (
<#list model.requestParams as param><#if util.getGoType(param.type)?contains("Data") || util.getFirstGenericParameterType(param.type)?contains("Data") || util.getSecondGenericParameterType(param.type)?contains("Data")><#global isImported=true>. "github.com/hazelcast/hazelcast-go-client/internal/serialization"<#break></#if></#list>
<#list model.events as event><#list event.eventParams as param><#if isImported><#break></#if><#if util.getGoType(param.type)?contains("Data") ><#global isImported=true>. "github.com/hazelcast/hazelcast-go-client/internal/serialization"<#break></#if></#list></#list>
<#list model.responseParams as param><#if isImported><#break></#if><#if util.getGoType(param.type)?contains("Data") ><#global isImported=true>. "github.com/hazelcast/hazelcast-go-client/internal/serialization"<#break></#if></#list>
<#list model.requestParams as param><#if util.getGoType(param.type) == "int32" || util.getGoType(param.type)?contains("[]") || util.getGoType(param.type) == "int64" || util.getGoType(param.type) == "bool" || util.getGoType(param.type) == "int64" ||util.getGoType(param.type) == "[]byte" || util.getGoType(param.type) == "[]int64">. "github.com/hazelcast/hazelcast-go-client/internal/common"<#break></#if></#list>
)
<#--************************ REQUEST ********************************************************-->

func ${model.parentName}${model.name?cap_first}CalculateSize(<#list model.requestParams as param>${param.name} ${util.getGoPointerType(param.type)}<#if param_has_next>, </#if></#list>) int {
    // Calculates the request payload size
    dataSize := 0
<#list model.requestParams as p>
    <@sizeText var_name=p.name type=p.type isNullable=p.nullable/>
</#list>
    return dataSize
}

func ${model.parentName}${model.name?cap_first}EncodeRequest(<#list model.requestParams as param>${param.name} ${util.getGoPointerType(param.type)}<#if param_has_next>, </#if></#list>) *ClientMessage {
    // Encode request into clientMessage
    clientMessage := NewClientMessage(nil, ${model.parentName}${model.name?cap_first}CalculateSize(<#list model.requestParams as param>${param.name}<#if param_has_next>, </#if></#list>))
    clientMessage.SetMessageType(${model.parentName?upper_case}_${model.name?upper_case})
    clientMessage.IsRetryable =<#if model.retryable == 1>true<#else>false</#if>
<#list model.requestParams as p>
<@setterText var_name=p.name type=p.type isNullable=p.nullable/>
</#list>
    clientMessage.UpdateFrameLength()
    return clientMessage
}

<#--************************ RESPONSE ********************************************************-->
<#if model.responseParams?has_content>
func ${model.parentName}${model.name?cap_first}DecodeResponse(clientMessage *ClientMessage) func()(<#list model.responseParams as p>${p.name} ${util.getGoPointerType(p.type)}<#if p_has_next>, </#if></#list>) {
    // Decode response from client message
    return func()(<#list model.responseParams as p>${p.name} ${util.getGoPointerType(p.type)}<#if p_has_next>, </#if></#list>) {
<#list model.responseParams as p>
    <#if p.versionChanged >
        if clientMessage.IsComplete() {
            return
        }
    </#if>
<@getterText var_name=p.name type=p.type isNullable=p.nullable indent=2/>
</#list>
        return
    }
}
<#else>// Empty decodeResponse(clientMessage), this message has no parameters to decode
</#if>

<#--************************ EVENTS ********************************************************-->
<#if model.events?has_content>
<#--HANDLER FUNC TYPE DEF'S-->
<#list model.events as event>
type ${model.parentName}${model.name?cap_first}HandleEvent${event.name?cap_first}Func func(<#list event.eventParams as p>${util.getGoPointerType(p.type)}<#if p_has_next>, </#if></#list>)
</#list>

<#--HANDLER DECODER FUNC'S-->
<#list model.events as event>
func ${model.parentName}${model.name?cap_first}Event${event.name?cap_first}Decode(clientMessage *ClientMessage)(<#list event.eventParams as p>${p.name} ${util.getGoPointerType(p.type)}<#if p_has_next>, </#if></#list>) {
    <#list event.eventParams as p>
        <#if p.versionChanged >
    if clientMessage.IsComplete() {
        return
    }
        </#if>
    <@getterText var_name=p.name type=p.type isNullable=p.nullable indent=2/>
    </#list>
    return
}
</#list>

func ${model.parentName}${model.name?cap_first}Handle(clientMessage *ClientMessage,
    <#list model.events as event>handleEvent${event.name?cap_first} ${model.parentName}${model.name?cap_first}HandleEvent${event.name?cap_first}Func<#if event_has_next>,
</#if></#list>){
    // Event handler
    messageType := clientMessage.MessageType()
    <#list model.events as event>
    if messageType == EVENT_${event.name?upper_case} && handleEvent${event.name?cap_first} != nil {
        handleEvent${event.name?cap_first}(${model.parentName}${model.name?cap_first}Event${event.name?cap_first}Decode(clientMessage))
    }
    </#list>
}
</#if>

<#--MACROS BELOW-->
<#--SIZE NULL CHECK MACRO -->
<#macro sizeText var_name type isNullable=false>
<#if isNullable>
    dataSize += BOOL_SIZE_IN_BYTES
    if ${var_name} != nil {
<@sizeTextInternal var_name=var_name type=type indent=2 isNullable=true/>
     }
<#else>
<@sizeTextInternal var_name=var_name type=type indent=1/>
</#if>
</#macro>

<#--METHOD PARAM MACRO -->
<#macro methodParam type><#local cat= util.getTypeCategory(type)>
<#switch cat>
<#case "COLLECTION"><#local genericType= util.getGenericType(type)>java.util.Collection<${genericType}><#break>
<#default>${type}
</#switch>
</#macro>

<#--SIZE MACRO -->
<#macro sizeTextInternal var_name type indent isNullable=false pointer=true>
<#local cat= util.getTypeCategory(type)>
<#switch cat>
    <#case "OTHER">
        <#if util.isPrimitive(type)>
${""?left_pad(indent * 4)}dataSize += ${util.getGoType(type)?upper_case}_SIZE_IN_BYTES
        <#else >
${""?left_pad(indent * 4)}dataSize += ${util.getGoType(type)?cap_first}CalculateSize(${var_name})
        </#if>
        <#break >
    <#case "CUSTOM">
${""?left_pad(indent * 4)}dataSize += ${util.getGoType(type)?cap_first}CalculateSize(${var_name})
        <#break >
    <#case "COLLECTION">
${""?left_pad(indent * 4)}dataSize += INT_SIZE_IN_BYTES
        <#local genericType= util.getGenericType(type)>
        <#local n= var_name>
${""?left_pad(indent * 4)}for _,${var_name}Item := range ${var_name}{
        <@sizeTextInternal var_name="${n}Item"  type=genericType indent=(indent + 1) pointer=false/>
        }
        <#break >
    <#case "ARRAY">
${""?left_pad(indent * 4)}dataSize += INT_SIZE_IN_BYTES
        <#local genericType= util.getArrayType(type)>
        <#local n= var_name>
${""?left_pad(indent * 4)}for range ${var_name}{
        <@sizeTextInternal var_name="${n}Item"  type=genericType indent=(indent + 1)/>
        }
        <#break >
    <#case "MAPENTRY">
        <#local keyType = util.getFirstGenericParameterType(type)>
        <#local valueType = util.getSecondGenericParameterType(type)>
        key := ${var_name}.key.(${util.getGoPointerType(keyType)})
        val := ${var_name}.value.(${util.getGoPointerType(valueType)})
        <@sizeTextInternal var_name="key"  type=keyType indent=indent/>
        <@sizeTextInternal var_name="val"  type=valueType indent=indent/>
</#switch>
</#macro>
<#--SETTER NULL CHECK MACRO -->
<#macro setterText var_name type isNullable=false>
<#local isNullVariableName= "${var_name}IsNil">
<#if isNullable>
    clientMessage.AppendBool(${var_name} == nil)
    if ${var_name} != nil {
<@setterTextInternal var_name=var_name type=type indent=2 isNullable=isNullable/>
    }
<#else>
<@setterTextInternal var_name=var_name type=type indent=1/>
</#if>
</#macro>

<#--SETTER MACRO -->
<#macro setterTextInternal var_name type indent isNullable=false pointer=true>
    <#local cat= util.getTypeCategory(type)>
    <#if cat == "OTHER">
${""?left_pad(indent * 4)}clientMessage.Append${util.getGoType(type)?cap_first}(${var_name})
    </#if>
    <#if cat == "CUSTOM">
${""?left_pad(indent * 4)}<#if type?contains("UUID")>UuidCodec<#else>${util.getTypeCodec(type)?split(".")?last}</#if>Encode(clientMessage, ${var_name})
    </#if>
    <#if cat == "COLLECTION">
${""?left_pad(indent * 4)}clientMessage.AppendInt32(int32(len(${var_name})))
        <#local itemType = util.getGenericType(type)>
        <#local itemTypeVar= var_name + "Item">
${""?left_pad(indent * 4)}for _,${itemTypeVar} := range ${var_name}{
    <@setterTextInternal var_name=itemTypeVar type=itemType indent=(indent + 1) pointer=false />
${""?left_pad(indent * 4)}}
    </#if>
    <#if cat == "ARRAY">
${""?left_pad(indent * 4)}clientMessage.AppendInt32(int32(len(${var_name})))
        <#local itemType= util.getArrayType(type)>
        <#local itemTypeVar= var_name + "Item">
${""?left_pad(indent * 4)}for _,${itemTypeVar} := range ${var_name}{
    <@setterTextInternal var_name=itemTypeVar  type=itemType indent=(indent + 1) />
${""?left_pad(indent * 4)}}
    </#if>
    <#if cat == "MAPENTRY">
        <#local keyType = util.getFirstGenericParameterType(type)>
        <#local valueType = util.getSecondGenericParameterType(type)>
                key := ${var_name}.key.(${util.getGoPointerType(keyType)})
                val := ${var_name}.value.(${util.getGoPointerType(valueType)})
    <@setterTextInternal var_name="key"  type=keyType indent=indent/>
    <@setterTextInternal var_name="val"  type=valueType indent=indent/>
     </#if>
</#macro>

<#--GETTER NULL CHECK MACRO -->
<#macro getterText var_name type isNullable=false isEvent=false indent=1>
<#if isNullable><#if (isEvent)>${""?left_pad(indent * 4)}var ${var_name} <#if !util.isPrimitive(type)>*</#if>${util.modifyForGoTypes(type?split(".")?last)}</#if>
${""?left_pad(indent * 4)}if !clientMessage.ReadBool(){
<@getterTextInternal var_name=var_name varType=type isEvent=isEvent indent=indent +1 isNullable=isNullable/>
${""?left_pad(indent * 4)}}
<#else>
<@getterTextInternal var_name=var_name varType=type isEvent=isEvent indent= indent/>
</#if>
</#macro>

<#macro getterTextInternal var_name varType indent isEvent=false isCollection=false isNullable=false>
<#local cat= util.getTypeCategory(varType)>
<#local isDeserial= !(isEvent || isCollection)>
<#switch cat>
    <#case "OTHER">
        <#switch varType>
            <#case util.DATA_FULL_NAME>
${""?left_pad(indent * 4)}<#if !(isEvent || isCollection)>${var_name}<#else>${var_name} <#if isNullable==false>:</#if></#if>= clientMessage.ReadData()
                <#break >
            <#case "java.lang.Integer">
${""?left_pad(indent * 4)}<#if !(isEvent || isCollection)>${var_name}<#else>${var_name} <#if isNullable==false>:</#if></#if>= clientMessage.ReadInt32()
                <#break >
            <#case "java.lang.Boolean">
${""?left_pad(indent * 4)}<#if !(isEvent || isCollection)>${var_name}<#else>${var_name} <#if isNullable==false>:</#if></#if>= clientMessage.ReadBool()
                <#break >
            <#case "java.lang.String">
${""?left_pad(indent * 4)}<#if !(isEvent || isCollection)>${var_name}<#else>${var_name} <#if isNullable==false>:</#if></#if>= clientMessage.ReadString()
                <#break >
            <#case "java.util.Map.Entry<com.hazelcast.nio.serialization.Data,com.hazelcast.nio.serialization.Data>">
${""?left_pad(indent * 4)}<#if !(isEvent || isCollection)>${var_name}<#else>${var_name} <#if isNullable==false>:</#if></#if>= Pair{clientMessage.ReadData(), clientMessage.ReadData()}
                <#break >
            <#default>
${""?left_pad(indent * 4)}<#if !(isEvent || isCollection)>${var_name}<#else>${var_name} <#if isNullable==false>:</#if></#if>= clientMessage.Read${util.getGoType(varType)?cap_first}()
        </#switch>
        <#break >
    <#case "CUSTOM">
${""?left_pad(indent * 4)}<#if !(isEvent || isCollection)>${var_name}<#else>${var_name} <#if isNullable==false>:</#if></#if>= <#if varType?contains("UUID")>UuidCodec<#else>${util.getTypeCodec(varType)?split(".")?last}</#if>Decode(clientMessage)
        <#break >
    <#case "COLLECTION">
    <#case "ARRAY">
    <#if cat == "COLLECTION">
    <#local itemVariableType= util.getGenericType(varType)>
    <#else>
    <#local itemVariableType= util.getArrayType(varType)>
    </#if>
    <#local itemVariableName= "${var_name}Item">
    <#local sizeVariableName= "${var_name}Size">
    <#local indexVariableName= "${var_name}Index">
${""?left_pad(indent * 4)}${sizeVariableName} := clientMessage.ReadInt32()
${""?left_pad(indent * 4)}${var_name} = make([]${util.getGoPointerType(itemVariableType)}, ${sizeVariableName})
${""?left_pad(indent * 4)}for ${indexVariableName} := 0 ; ${indexVariableName} < int(${sizeVariableName}) ; ${indexVariableName} ++ {
            <@getterTextInternal var_name=itemVariableName varType=itemVariableType isEvent=isEvent isCollection=true indent=(indent +1)/>
${""?left_pad(indent * 4)}    ${var_name}[${indexVariableName}] = ${itemVariableName}
${""?left_pad(indent * 4)}}
        <#break >
    <#case "MAPENTRY">
        <#local sizeVariableName= "${var_name}Size">
        <#local indexVariableName= "${var_name}Index">
        <#local keyType = util.getFirstGenericParameterType(varType)>
        <#local valueType = util.getSecondGenericParameterType(varType)>
        <#local keyVariableName= "${var_name}Key">
        <#local valVariableName= "${var_name}Value">
            <@getterTextInternal var_name=keyVariableName varType=keyType isEvent=true indent=indent/>
            <@getterTextInternal var_name=valVariableName varType=valueType isEvent=true indent=indent/>
${""?left_pad(indent * 4)}var ${var_name} = &Pair{ key:${keyVariableName}, value:${valVariableName}}
</#switch>
</#macro>
