# XML nodes

abstract AbstractXMLNode

#### Types of attributes

const XML_ATTRIBUTE_CDATA = 1
const XML_ATTRIBUTE_ID = 2
const XML_ATTRIBUTE_IDREF = 3
const XML_ATTRIBUTE_IDREFS = 4
const XML_ATTRIBUTE_ENTITY = 5
const XML_ATTRIBUTE_ENTITIES = 6
const XML_ATTRIBUTE_NMTOKEN = 7
const XML_ATTRIBUTE_NMTOKENS = 8
const XML_ATTRIBUTE_ENUMERATION = 9
const XML_ATTRIBUTE_NOTATION = 10

#### Types of nodes

const XML_ELEMENT_NODE = 1
const XML_ATTRIBUTE_NODE = 2
const XML_TEXT_NODE = 3
const XML_CDATA_SECTION_NODE = 4
const XML_ENTITY_REF_NODE = 5
const XML_ENTITY_NODE = 6
const XML_PI_NODE = 7
const XML_COMMENT_NODE = 8
const XML_DOCUMENT_NODE = 9
const XML_DOCUMENT_TYPE_NODE = 10
const XML_DOCUMENT_FRAG_NODE = 11
const XML_NOTATION_NODE = 12
const XML_HTML_DOCUMENT_NODE = 13
const XML_DTD_NODE = 14
const XML_ELEMENT_DECL = 15
const XML_ATTRIBUTE_DECL = 16
const XML_ENTITY_DECL = 17
const XML_NAMESPACE_DECL = 18
const XML_XINCLUDE_START = 19
const XML_XINCLUDE_END = 20
const XML_DOCB_DOCUMENT_NODE = 21

##### Generic methods

is_elementnode(nd::AbstractXMLNode) = (nodetype(nd) == XML_ELEMENT_NODE)
is_textnode(nd::AbstractXMLNode) = (nodetype(nd) == XML_TEXT_NODE)
is_commentnode(nd::AbstractXMLNode) = (nodetype(nd) == XML_COMMENT_NODE)
is_cdatanode(nd::AbstractXMLNode) = (nodetype(nd) == XML_CDATA_SECTION_NODE)


#######################################
#
#  XML Attributes
#
#######################################

immutable _XMLAttrStruct
    # common part
    _private::Ptr{Void}
    nodetype::Cint
    name::Xstr
    children::Xptr
    last::Xptr
    parent::Xptr
    next::Xptr
    prev::Xptr
    doc::Xptr

    # specific part
    ns::Xptr
    atype::Cint
    psvi::Ptr{Void}
end

type XMLAttr
    ptr::Xptr
    _struct::_XMLAttrStruct

    function XMLAttr(ptr::Xptr)
        s = unsafe_load(convert(Ptr{_XMLAttrStruct}, ptr))
        @assert s.nodetype == XML_ATTRIBUTE_NODE
        new(ptr, s)
    end
end

name(a::XMLAttr) = unsafe_string(a._struct.name)

function value(a::XMLAttr)
    pct = ccall((:xmlNodeGetContent,libxml2), Xstr, (Xptr,), a._struct.children)
    (pct != C_NULL ? _xcopystr(pct) : "")::AbstractString
end

# iterations

immutable XMLAttrIter
    p::Xptr
end

Base.start(it::XMLAttrIter) = it.p
Base.done(it::XMLAttrIter, p::Xptr) = (p == C_NULL)
Base.next(it::XMLAttrIter, p::Xptr) = (a = XMLAttr(p); (a, a._struct.next))
iteratorsize(::Type{XMLAttrIter}) = SizeUnknown()

#######################################
#
#  Base XML Nodes
#
#######################################

immutable _XMLNodeStruct
    # common part
    _private::Ptr{Void}
    nodetype::Cint
    name::Ptr{UInt8}
    children::Xptr
    last::Xptr
    parent::Xptr
    next::Xptr
    prev::Xptr
    doc::Xptr

    # specific part
    ns::Xptr
    content::Xstr
    attrs::Xptr
    nsdef::Xptr
    psvi::Ptr{Void}
    line::Cushort
    extra::Cushort
end

type XMLNode <: AbstractXMLNode
    ptr::Xptr
    _struct::_XMLNodeStruct

    function XMLNode(ptr::Xptr)
        s = unsafe_load(convert(Ptr{_XMLNodeStruct}, ptr))
        new(ptr, s)
    end
end

name(nd::XMLNode) = unsafe_string(nd._struct.name)
nodetype(nd::XMLNode) = nd._struct.nodetype
has_children(nd::XMLNode) = (nd._struct.children != C_NULL)

# whether it is a white-space only text node
is_blanknode(nd::XMLNode) = @compat Bool(ccall((:xmlIsBlankNode,libxml2), Cint, (Xptr,), nd.ptr))

function free(nd::XMLNode)
    ccall((:xmlFreeNode,libxml2), Void, (Xptr,), nd.ptr)
    nd.ptr = C_NULL
end

function unlink(nd::XMLNode)
    ccall((:xmlUnlinkNode,libxml2), Void, (Xptr,), nd.ptr)
end

# iteration over children

immutable XMLNodeIter
    p::Xptr
end

Base.start(it::XMLNodeIter) = it.p
Base.done(it::XMLNodeIter, p::Xptr) = (p == C_NULL)
Base.next(it::XMLNodeIter, p::Xptr) = (nd = XMLNode(p); (nd, nd._struct.next))
iteratorsize(::Type{XMLNodeIter}) = SizeUnknown()

child_nodes(nd::XMLNode) = XMLNodeIter(nd._struct.children)

function content(nd::XMLNode)
    pct = ccall((:xmlNodeGetContent,libxml2), Xstr, (Xptr,), nd.ptr)
    (pct != C_NULL ? _xcopystr(pct) : "")::AbstractString
end

# dumping

const DEFAULT_DUMPBUFFER_SIZE = 4096

function Base.string(nd::XMLNode)
    buf = XBuffer(DEFAULT_DUMPBUFFER_SIZE)
    ccall((:xmlNodeDump,libxml2), Cint, (Xptr, Xptr, Xptr, Cint, Cint),
        buf.ptr, nd._struct.doc, nd.ptr, 0, 1)
    r = content(buf)
    free(buf)
    return r
end

Base.show(io::IO, nd::XMLNode) = print(io, string(nd))


#######################################
#
#  XML Elements
#
#######################################

type XMLElement <: AbstractXMLNode
    node::XMLNode

    function XMLElement(node::XMLNode)
        if !is_elementnode(node)
            throw(ArgumentError("The input node is not an element."))
        end
        new(node)
    end

    XMLElement(ptr::Xptr) = XMLElement(XMLNode(ptr))
end

name(x::XMLElement) = name(x.node)
nodetype(x::XMLElement) = XML_ELEMENT_NODE
has_children(x::XMLElement) = has_children(x.node)
child_nodes(x::XMLElement) = child_nodes(x.node)
content(x::XMLElement) = content(x.node)

Base.string(x::XMLElement) = string(x.node)
Base.show(io::IO, x::XMLElement) = show(io, x.node)

free(x::XMLElement) = free(x.node)
unlink(x::XMLElement) = unlink(x.node)

# attribute access

function attribute(x::XMLElement, name::AbstractString; required::Bool=false)
    pv = ccall((:xmlGetProp,libxml2), Xstr, (Xptr, Cstring), x.node.ptr, name)
    if pv != C_NULL
        return _xcopystr(pv)
    else
        if required
            throw(XMLAttributeNotFound())
        else
            return nothing
        end
    end
end

function has_attribute(x::XMLElement, name::AbstractString)
    p = ccall((:xmlHasProp,libxml2), Xptr, (Xptr, Cstring), x.node.ptr, name)
    return p != C_NULL
end

has_attributes(x::XMLElement) = (x.node._struct.attrs != C_NULL)
attributes(x::XMLElement) = XMLAttrIter(x.node._struct.attrs)

function attributes_dict(x::XMLElement)
    # make an dictionary based on attributes

    dct = Dict{AbstractString,AbstractString}()
    if has_attributes(x)
        for a in attributes(x)
            dct[name(a)] = value(a)
        end
    end
    return dct
end


# element access

immutable XMLElementIter
    parent_ptr::Xptr
end

Base.start(it::XMLElementIter) = ccall((:xmlFirstElementChild,libxml2), Xptr, (Xptr,), it.parent_ptr)
Base.done(it::XMLElementIter, p::Xptr) = (p == C_NULL)
Base.next(it::XMLElementIter, p::Xptr) = (XMLElement(p), ccall((:xmlNextElementSibling,libxml2), Xptr, (Xptr,), p))
iteratorsize(::Type{XMLElementIter}) = SizeUnknown()

child_elements(x::XMLElement) = XMLElementIter(x.node.ptr)

# elements by tag name

function find_element(x::XMLElement, n::AbstractString)
    for c in child_elements(x)
        if name(c) == n
            return c
        end
    end
    return nothing
end

function get_elements_by_tagname(x::XMLElement, n::AbstractString)
    lst = Array(XMLElement, 0)
    for c in child_elements(x)
        if name(c) == n
            push!(lst, c)
        end
    end
    return lst
end

Base.getindex(x::XMLElement, name::AbstractString) = get_elements_by_tagname(x, name)


#######################################
#
#  XML Tree Construction
#
#######################################

function new_element(name::AbstractString)
    p = ccall((:xmlNewNode,libxml2), Xptr, (Xptr, Cstring), C_NULL, name)
    XMLElement(p)
end

function add_child(xparent::XMLElement, xchild::XMLNode)
    p = ccall((:xmlAddChild,libxml2), Xptr, (Xptr, Xptr), xparent.node.ptr, xchild.ptr)
    p != C_NULL || throw(XMLTreeError("Failed to add a child node."))
end

add_child(xparent::XMLElement, xchild::XMLElement) = add_child(xparent, xchild.node)

function new_child(xparent::XMLElement, name::AbstractString)
    xc = new_element(name)
    add_child(xparent, xc)
    return xc
end

function new_textnode(txt::AbstractString)
    p = ccall((:xmlNewText,libxml2), Xptr, (Cstring,), txt)
    XMLNode(p)
end

add_text(x::XMLElement, txt::AbstractString) = add_child(x, new_textnode(txt))

function set_attribute(x::XMLElement, name::AbstractString, val::AbstractString)
    a = ccall((:xmlSetProp,libxml2), Xptr, (Xptr, Cstring, Cstring), x.node.ptr, name, val)
    return XMLAttr(a)
end

set_attribute(x::XMLElement, name::AbstractString, val) = set_attribute(x, name, string(val))

if VERSION < v"0.4.0-dev+980"
    const PairTypes = NTuple{2}
else
    const PairTypes = @compat Union{NTuple{2}, Pair}
end

function set_attributes{P<:PairTypes}(x::XMLElement, attrs::AbstractArray{P})
    for (nam, val) in attrs
        set_attribute(x, string(nam), string(val))
    end
end

set_attributes(x::XMLElement, attrs::Associative) = set_attributes(x, collect(attrs))

function set_attributes(x::XMLElement; attrs...)
    for (nam, val) in attrs
        set_attribute(x, string(nam), string(val))
    end
end

function set_content(x::XMLElement, txt::AbstractString)
    ccall((:xmlNodeSetContent, libxml2), Xptr, (Xptr, Cstring,), x.node.ptr, txt)
    x
end
