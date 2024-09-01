<template>
  <div class="edit-client">
    <Toaster :active="success" message="Client has been updated" type="success" />
    <div class="container">
      <div class="ui stackable grid">
        <div class="four wide column">
          <div class="sidebar">
            <div class="ui segment">
              <div class="ui attribute list">
                <div class="item">
                  <span class="header">Client ID</span>
                  <span class="description">{{ client.id }}</span>
                </div>
              </div>
            </div>
            <div class="ui urls info message">
              <div><strong>OpenIDConfiguration:</strong> {{ openidConfigurationUrl }}</div>
              <div><strong>AuthorizeUrl:</strong> {{ authorizeUrl }}</div>
              <div><strong>TokenUrl:</strong> {{ tokenUrl }}</div>
            </div>
            <router-link :to="{ name: 'client-list' }" class="ui right floated button">Back</router-link>
          </div>
        </div>
        <div class="twelve wide column">
          <ClientForm :client="client" @submit="updateClient()" @back="back()" action="Update" />
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import Client from '../../models/client.model'
import ClientForm from '../../components/Forms/ClientForm.vue'
import Toaster from '../../components/Toaster.vue'

export default {
  name: 'clients',
  components: {
    ClientForm,
    Toaster
  },
  mounted () {
    const { clientId } = this.$route.params
    Client.get(clientId).then((client) => {
      this.client = client
    })
  },
  data () {
    return {
      errors: null,
      scopes: [],
      success: false,
      client: new Client()
    }
  },
  computed: {
    authorizeUrl () {
      return window.env.BORUTA_OAUTH_BASE_URL + '/oauth/authorize'
    },
    tokenUrl () {
      return window.env.BORUTA_OAUTH_BASE_URL + '/oauth/token'
    },
    openidConfigurationUrl () {
      return window.env.BORUTA_OAUTH_BASE_URL + '/.well-known/openid-configuration'
    },
  },
  methods: {
    updateClient () {
      this.success = false
      return this.client.save().then(() => {
        this.success = true
      }).catch()
    }
  }
}
</script>
