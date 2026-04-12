package com.markdown.parser

import org.json.JSONArray
import org.json.JSONObject

data class ASTNode(
    val type: Int,
    val content: String = "",
    val headingLevel: Int = 0,
    val ordered: Boolean = false,
    val listStart: Int = 1,
    val listTight: Boolean = false,
    val isTask: Boolean = false,
    val taskChecked: Boolean = false,
    val lang: String = "",
    val align: Int = 0,
    val cols: Int = 0,
    val url: String = "",
    val title: String = "",
    val src: String = "",
    val imgTitle: String = "",
    val autolink: Boolean = false,
    val tag: String = "",
    val props: Map<String, String> = emptyMap(),
    val children: List<ASTNode> = emptyList()
) {
    companion object {
        // Node type constants matching C++ enum
        const val DOCUMENT = 0
        const val PARAGRAPH = 1
        const val HEADING = 2
        const val BLOCKQUOTE = 3
        const val LIST = 4
        const val LIST_ITEM = 5
        const val CODE_BLOCK = 6
        const val THEMATIC_BREAK = 7
        const val TABLE = 8
        const val TABLE_HEAD = 9
        const val TABLE_BODY = 10
        const val TABLE_ROW = 11
        const val TABLE_CELL = 12
        const val HTML_BLOCK = 13
        const val TEXT = 14
        const val SOFT_BREAK = 15
        const val LINE_BREAK = 16
        const val CODE = 17
        const val EMPHASIS = 18
        const val STRONG = 19
        const val STRIKETHROUGH = 20
        const val LINK = 21
        const val IMAGE = 22
        const val HTML_INLINE = 23
        const val CUSTOM_TAG = 24

        fun fromJSON(json: JSONObject): ASTNode {
            val childrenArray = json.optJSONArray("children")
            val children = mutableListOf<ASTNode>()
            if (childrenArray != null) {
                for (i in 0 until childrenArray.length()) {
                    children.add(fromJSON(childrenArray.getJSONObject(i)))
                }
            }

            val propsObj = json.optJSONObject("props")
            val props = mutableMapOf<String, String>()
            if (propsObj != null) {
                val keys = propsObj.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    props[key] = propsObj.getString(key)
                }
            }

            return ASTNode(
                type = json.getInt("type"),
                content = json.optString("content", ""),
                headingLevel = json.optInt("headingLevel", 0),
                ordered = json.optBoolean("ordered", false),
                listStart = json.optInt("listStart", 1),
                listTight = json.optBoolean("listTight", false),
                isTask = json.optBoolean("isTask", false),
                taskChecked = json.optBoolean("taskChecked", false),
                lang = json.optString("lang", ""),
                align = json.optInt("align", 0),
                cols = json.optInt("cols", 0),
                url = json.optString("url", ""),
                title = json.optString("title", ""),
                src = json.optString("src", ""),
                imgTitle = json.optString("imgTitle", ""),
                autolink = json.optBoolean("autolink", false),
                tag = json.optString("tag", ""),
                props = props,
                children = children
            )
        }
    }
}

object ParserBridge {
    init {
        System.loadLibrary("react-native-markdown")
    }

    fun parse(
        markdown: String,
        customTags: List<String> = emptyList(),
        tables: Boolean = true,
        strikethrough: Boolean = true,
        taskLists: Boolean = true,
        autolinks: Boolean = true
    ): ASTNode {
        val tagsStr = customTags.joinToString(",")
        val json = nativeParse(markdown, tagsStr, tables, strikethrough, taskLists, autolinks)
        return ASTNode.fromJSON(JSONObject(json))
    }

    private external fun nativeParse(
        markdown: String,
        customTags: String,
        tables: Boolean,
        strikethrough: Boolean,
        taskLists: Boolean,
        autolinks: Boolean
    ): String
}
