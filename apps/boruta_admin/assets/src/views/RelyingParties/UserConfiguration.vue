<template>
  <div class="user-list">
    <div class="main header">
      <h1>User configuration</h1>
    </div>
    <div class="ui container">
      <div class="ui large segment">
        <form class="ui large form" v-on:submit.prevent="submit()">
          <h3>Registration</h3>
          <div class="field">
            <div class="ui info message">
              <p>This configuration determines if users can create accounts for this instance. If set to true any user will be able to create accounts.</p>
              <p>Created accounts will have no scopes attached to them, user roles is a feature that will be soon be available.</p>
            </div>
            <div class="ui toggle checkbox">
              <input type="checkbox" v-model="configuration.registrable">
              <label>Registrable</label>
            </div>
          </div>
        </form>
      </div>
      <div class="ui large segment">
        <form class="ui large form" v-on:submit.prevent="submit()">
          <h3>Accounts confirmation</h3>
          <div class="field">
            <div class="ui info message">
              <p>This configuration determines if users must be confirmed after account creation. If set to true, users will receive an email with instructions in order to confirm their account.</p>
              <p>Soon authorization server will have a configuration that would restrict access to confirmed accounts.</p>
            </div>
            <div class="ui toggle checkbox">
              <input type="checkbox" v-model="configuration.confirmable">
              <label>Confirmable</label>
            </div>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: 'user-list',
  data () {
    return { configuration: {} }
  },
  mounted () {
    this.getConfiguration()
  },
  methods: {
    submit () {},
    getConfiguration () {}
  }
}
</script>

<style scoped lang="scss">
</style>
