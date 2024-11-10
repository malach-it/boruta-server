<template>
  <div class="federation-entity-form">
    <div class="ui segment">
      <FormErrors v-if="federationEntity.errors" :errors="federationEntity.errors" />
      <form class="ui form" @submit.prevent="submit">
        <div class="field" :class="{ 'error': federationEntity.errors?.organization_name }">
          <label>Organization name</label>
          <input type="text" v-model="federationEntity.organization_name" placeholder="administrator" />
        </div>
        <div class="field" :class="{ 'error': federationEntity.errors?.type }">
          <label>Type</label>
          <select v-model="federationEntity.type">
            <option v-for="type in entityTypes" :value="type">{{ type }}</option>
          </select>
        </div>
        <div class="field" :class="{ 'error': federationEntity.errors?.authorities }">
          <label>Authorities</label>
          <div v-for="(authority, index) in federationEntity.authorities" class="field" :key="index">
            <div class="ui right icon input">
              <input type="text" v-model="authority.url" placeholder="http://authority.uri" />
              <i v-on:click="deleteAuthority(authority)" class="close icon"></i>
            </div>
          </div>
          <a v-on:click.prevent="addAuthority()" class="ui blue fluid button">Add an authority</a>
        </div>
        <h3>Key type</h3>
        <div class="field" :class="{ 'error': federationEntity.errors?.key_pair_type }">
          <select v-model="federationEntity.key_pair_type.type">
            <option v-for="keyPairType in Object.keys(keyPairTypes)" :value="keyPairType" :key="keyPairType">
              {{ keyPairType }}
            </option>
          </select>
        </div>
        <div v-for="(value, param) in keyPairTypes[federationEntity.key_pair_type.type]" class="field" :class="{ 'error': federationEntity.errors?.key_pair_type }">
          <label>{{ param }}</label>
          <select v-if="value instanceof Array" v-model="federationEntity.key_pair_type[param]">
            <option v-for="option in value" :value="option" :key="option">
              {{ option }}
            </option>
          </select>
          <input v-else type="text" v-model="federationEntity.key_pair_type[param]" />
        </div>
        <div class="ui segment">
          <div class="inline fields" :class="{ 'error': federationEntity.errors?.trust_chain_statement_alg }">
            <label>Trust chain statement JWT signature algorithm</label>
            <div class="field" v-for="alg in statementSignatureAlgorithms" :key="alg">
              <div class="ui radio checkbox">
                <label>{{ alg }}</label>
                <input type="radio" v-model="federationEntity.trust_chain_statement_alg" :value="alg" />
              </div>
            </div>
          </div>
        </div>
        <div class="field" :class="{ 'error': federationEntity.errors?.trust_chain_statement_ttl }">
          <label>Trust chain statement TTL</label>
          <input type="number" v-model="federationEntity.trust_chain_statement_ttl" />
        </div>
        <hr />
        <button class="ui right floated violet button" type="submit">{{ action }}</button>
        <a class="ui button" v-on:click="back()">Back</a>
      </form>
    </div>
  </div>
</template>

<script>
import FederationEntity from '../../models/federation-entity.model.js'
import FormErrors from '../../components/Forms/FormErrors.vue'

export default {
  name: 'federation-entity-form',
  props: ['federation-entity', 'action'],
  components: {
    FormErrors
  },
  data () {
    return {
      keyPairTypes: FederationEntity.keyPairTypes,
      entityTypes: FederationEntity.types,
      statementSignatureAlgorithms: FederationEntity.statementSignatureAlgorithms
    }
  },
  methods: {
    addAuthority () {
      this.federationEntity.authorities.push({})
    },
    deleteAuthority (authority) {
    console.log(this.federationEntity)
      this.federationEntity.authorities.splice(this.federationEntity.authorities.indexOf(authority), 1)
    },
    back () {
      this.$emit('back')
    }
  }
}
</script>

<style scoped lang="scss">
.federation-entity-form {
  .field {
    position: relative;
    &.federation-entitys input {
      margin-right: 3em;
    }
  }
  .ui.icon.input>i.icon.close {
    cursor: pointer;
    pointer-events: all;
    position: absolute;
  }
  .authorized-scopes-select {
    margin-right: 3em;
  }
}
</style>
