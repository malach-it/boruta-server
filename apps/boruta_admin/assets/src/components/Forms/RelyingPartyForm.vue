<template>
  <div class="relying-party-form">
    <div class="ui large segment">
      <FormErrors v-if="relyingParty.errors" :errors="relyingParty.errors" />
      <form class="ui form" v-on:submit.prevent="submit()">
        <h3>General configuration</h3>
        <div class="field">
          <label>Name</label>
          <input type="text" v-model="relyingParty.name" placeholder="Super relying party">
        </div>
        <div class="field">
          <label>Type</label>
          <select v-model="relyingParty.type">
            <option value="internal">internal</option>
          </select>
        </div>
        <hr />
        <button class="ui large right floated violet button" type="submit">{{ action }}</button>
        <a class="ui large button" v-on:click="back()">Back</a>
      </form>
    </div>
  </div>
</template>

<script>
import FormErrors from '@/components/Forms/FormErrors.vue'

export default {
  name: 'relying-party-form',
  props: ['relyingParty', 'action'],
  components: {
    FormErrors
  },
  methods: {
    back () {
      this.$emit('back')
    },
    submit () {
      this.$emit('submit', this.relyingParty)
    }
  }
}
</script>

<style scoped lang="scss">
.relying-party-form {}
</style>
