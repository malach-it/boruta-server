<template>
  <div class="backend-form">
    <div class="ui segment">
      <FormErrors :errors="backend.errors" v-if="backend.errors" />
      <form class="ui form" @submit.prevent="submit">
        <div class="field">
          <label>Type</label>
          <select v-model="backend.type">
            <option value="Elixir.BorutaIdentity.Accounts.Internal">internal</option>
          </select>
        </div>
        <div class="field">
          <label>Name</label>
          <input type="text" v-model="backend.name" placeholder="Shiny new backend">
        </div>
        <div class="field">
          <div class="ui toggle checkbox">
            <input type="checkbox" v-model="backend.is_default" placeholder="Shiny new backend">
            <label>Default</label>
          </div>
        </div>
        <div class="ui info message">
          Default backend will be used in case of resource owner password credentials requests.
        </div>
        <hr />
        <button class="ui right floated violet button" type="submit">{{ action }}</button>
        <a v-on:click="back()" class="ui button">Back</a>
      </form>
    </div>
  </div>
</template>

<script>
import FormErrors from './FormErrors.vue'

export default {
  name: 'backend-form',
  props: ['backend', 'action'],
  components: {
    FormErrors
  },
  methods: {
    back () {
      this.$emit('back')
    }
  }
}
</script>
