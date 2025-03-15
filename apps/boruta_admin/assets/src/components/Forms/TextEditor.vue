<template>
  <div class="text-editor">
    <div class="editor lang-markup" ref="editor"></div>
  </div>
</template>

<script>
import { CodeJar } from 'codejar'
import { withLineNumbers } from 'codejar/linenumbers'
import { highlight, languages } from 'prismjs'

export default {
  name: 'TextEditor',
  props: ['content'],
  mounted () {
    const highlightFunc = (editor) => {
      const code = editor.textContent

      editor.innerHTML = highlight(code, languages.markup, 'markup')
    }

    const editor = CodeJar(this.$refs.editor, withLineNumbers(highlightFunc), {
      tab: ' '.repeat(2),
      spellcheck: false
    })

    editor.onUpdate(code => {
      this.$emit('codeUpdate', code)
    })

    this.editor = editor
    this.editor.updateCode(this.content)
  },
  watch: {
    content(newContent, content) {
      if (!content) this.editor.updateCode(this.content)
    }
  }
}
</script>

<style lang="scss">
.text-editor {
  height: 100%;
  width: 100%;
  overflow: hidden;
  .codejar-wrap {
    height: 100%;
    .codejar-linenumbers {
      color: orange !important;
      height: 100%;
      padding-left: .5em !important;
    }
    .editor {
      background: #f5f2f0;
      cursor: text;
      height: 100%;
      border-radius: 6px;
      box-shadow: 0 2px 2px 0 rgba(0, 0, 0, 0.14), 0 1px 5px 0 rgba(0, 0, 0, 0.12), 0 3px 1px -2px rgba(0, 0, 0, 0.2);
      font-family: 'Source Code Pro', monospace;
      font-weight: 400;
      letter-spacing: normal;
      line-height: 20px;
      tab-size: 4;
      .token.attr-name {
        color: #690;
      }
      .token.selector {
        color: #c90;
      }
    }
  }
}
</style>
