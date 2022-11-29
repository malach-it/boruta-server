<template>
  <div class="field edit-scopes">
    <div v-for="(scope, index) in currentScopes" class="field" :key="index">
      <div class="ui right icon input">
        <select type="text" v-model="scope.name" class="scopes-select">
          <option :value="scope.name" v-for="scope in scopes" :key="scope.id">{{ scope.name }}</option>
        </select>
        <i v-on:click="deleteScope(scope)" class="close icon"></i>
      </div>
    </div>
    <a v-on:click.prevent="addScope()" class="ui blue fluid button">Add a scope</a>
  </div>
</template>

<script>
export default {
  name: 'ScopesFieldByName',
  props: ['currentScopes', 'scopes'],
  methods: {
    deleteScope (scope) {
      this.$emit('delete-scope', scope)
    },
    addScope () {
      this.$emit('add-scope')
    }
  }
}
</script>

<style scoped lang="scss">
.edit-scopes {
  .ui.icon.input>i.icon.close {
    cursor: pointer;
    pointer-events: all;
  }
  .scopes-select {
    margin-right: 3em;
  }
}
</style>
