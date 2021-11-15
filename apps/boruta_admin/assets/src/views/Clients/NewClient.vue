<template>
  <div class="new-client">
    <div class="main header">
      <h1>New Client</h1>
    </div>
    <div class="ui container">
      <ClientForm :client="client" @submit="createClient()" @back="back()" action="Create" />
    </div>
  </div>
</template>

<script>
import Client from '@/models/client.model'
import ClientForm from '@/components/Forms/ClientForm.vue'

export default {
  name: 'clients',
  components: {
    ClientForm
  },
  data () {
    return {
      client: new Client()
    }
  },
  methods: {
    back () {
      this.$router.push({ name: 'client-list' })
    },
    createClient () {
      return this.client.save().then(() => {
        this.$router.push({ name: 'client-list' })
      }).catch()
    }
  }
}
</script>

<style scoped lang="scss">
.new-client {
  .ui.icon.input>i.icon.close {
    cursor: pointer;
    pointer-events: all;
  }
  .authorized-scopes-select {
    margin-right: 3em;
  }
}
</style>
