<template>
  <div class="key-pair-list">
    <Toaster :active="created" message="Key pair has been created" type="success" />
    <Toaster :active="rotated" message="Key pair has been rotated" type="success" />
    <Toaster :active="error" :message="error" type="error" />
    <Toaster :active="deleted" message="Key pair has been deleted" type="warning" />
    <a class="ui violet main create button" v-on:click="createKeyPair()">Add a key pair</a>
    <div class="container">
      <h2>Key pairs</h2>
      <div class="ui three column stackable grid">
        <div class="ui column" v-for="keyPair in keyPairs">
          <div class="ui key-pair segment">
            <div class="actions">
              <a v-on:click="setDefault(keyPair)" class="ui tiny blue button">default</a>
              <a v-on:click="rotate(keyPair)" class="ui tiny orange button">rotate</a>
              <a v-on:click="deleteKeyPair(keyPair)" class="ui tiny red button">delete</a>
            </div>
            <label><strong>Key pair ID</strong> {{ keyPair.id }}</label>
            <h3>Public key</h3>
            <pre>{{ keyPair.public_key }}</pre>
            <div class="ui default label" v-if="keyPair.is_default">default</div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import KeyPair from '../../models/key-pair.model'
import Toaster from '../../components/Toaster.vue'

export default {
  name: 'key-pair-list',
  components: {
    Toaster
  },
  data () {
    return {
      created: false,
      rotated: false,
      deleted: false,
      error: false,
      keyPairs: []
    }
  },
  mounted () {
    this.getKeyPairs()
  },
  methods: {
    getKeyPairs () {
      KeyPair.all().then(keyPairs => {
        this.keyPairs = keyPairs
      })
    },
    createKeyPair () {
      const keyPair = new KeyPair()

      this.created = false
      keyPair.save().then(keyPair => {
        this.keyPairs.push(keyPair)
        this.created = true
      })
    },
    setDefault (keyPair) {
      keyPair.is_default = true
      keyPair.save().then((keyPair) => {
        if (keyPair.is_default) {
          this.keyPairs.forEach(keyPair => keyPair.is_default = false)
          keyPair.is_default = true
        }
      }).catch(() => {
        keyPair.is_default = false
      })
    },
    rotate (keyPair) {
      if (!confirm('Are you sure?')) return
      this.rotated = false
      keyPair.rotate().then(() => {
        this.rotated = true
      })
    },
    deleteKeyPair (keyPair) {
      if (!confirm('Are you sure?')) return

      this.deleted = false
      this.error = false
      keyPair.destroy().then(() => {
        this.deleted = true
        this.keyPairs.splice(this.keyPairs.indexOf(keyPair), 1)
      }).catch(error => this.error = error.message)
    }
  }
}
</script>

<style scoped lang="scss">
.key-pair {
  padding-bottom: 1.6em;
  pre {
    overflow: hidden;
    overflow-x: scroll;
  }
  .default.label {
    position: absolute;
    bottom: 0;
    right: 0;
  }
}
</style>

