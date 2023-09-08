<template>
  <div class="organization-list">
    <Toaster :active="deleted" message="Organization has been deleted" type="warning" />
    <Toaster :active="errorMessage" :message="errorMessage" type="error" />
    <div class="main buttons">
      <router-link :to="{ name: 'new-organization' }" class="ui violet main create button">Add a organization</router-link>
    </div>
    <div class="container">
      <div class="ui info message">
        Organizations have many users as members. They help to group them and provide belongship.
      </div>
      <div class="ui three column stackable organizations grid" v-if="organizations.length">
        <div v-for="organization in organizations" class="column" :key="organization.id">
          <div class="ui organization highlightable segment">
            <div class="actions">
              <router-link
                :to="{ name: 'edit-organization', params: { organizationId: organization.id } }"
                class="ui tiny blue button">edit</router-link>
              <a v-on:click="deleteOrganization(organization)" class="ui tiny red button">delete</a>
            </div>
            <div class="ui attribute list">
              <div class="item">
                <span class="header">OrganizationId</span>
                <span class="description">{{ organization.id }}</span>
              </div>
              <div class="item">
                <span class="header">Name</span>
                <span class="description">{{ organization.name }}</span>
              </div>
              <div class="item">
                <span class="header">Label</span>
                <span class="description">{{ organization.label }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
      <hr />
      <div class="ui center aligned segment">
        <div class="total-entries">{{ totalEntries }} record(s)</div>
        <div class="ui pagination menu">
          <button
            :disabled="disableFirstPage"
            class="item"
            @click="goToPage(1)">
            &lt;
          </button>
          <button
            class="item"
            :class="{ 'active': currentPage == pageNumber }"
            v-for="pageNumber in meanPages"
            :key="pageNumber"
            @click="goToPage(pageNumber)">
            {{ pageNumber }}
          </button>
          <button
            :disabled="disableLastPage"
            class="item"
            @click="goToPage(this.totalPages)">
            &gt;
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { throttle } from 'lodash'
import Organization from '../../models/organization.model'
import Toaster from '../../components/Toaster.vue'

export default {
  name: 'organization-list',
  components: {
    Toaster
  },
  data () {
    return {
      organizations: [],
      deleted: false,
      errorMessage: false,
      currentPage: this.$route.query.page,
      totalPages: 1,
      totalEntries: 0,
      total_entries: 0
    }
  },
  computed: {
    throttledSearch () {
      return throttle(this.search, 500)
    },
    meanPages () {
      const meanPages = []

      let firstPage = this.currentPage - 1
      if (firstPage < 1) firstPage = 1
      let lastPage = firstPage + 2
      if (lastPage > this.totalPages) {
        lastPage = this.totalPages
        firstPage = lastPage - 2 < 1 ? 1 : lastPage - 2
      }

      for (let i = firstPage; i <= lastPage; i++) { meanPages.push(i) }

      return meanPages
    },
    disableFirstPage () {
      return this.meanPages[0] == 1
    },
    disableLastPage () {
      return this.meanPages.slice(-1) == this.totalPages
    }
  },
  methods: {
    getOrganizations (pageNumber, query) {
      Organization.all({ query, pageNumber }).then(({ data, currentPage, totalPages, totalEntries }) => {
        this.organizations = data
        this.totalPages = totalPages
        this.totalEntries = totalEntries
        this.currentPage = currentPage
      })
    },
    goToPage (pageNumber) {
      const query = { page: pageNumber }
      if (this.organizationQuery) query.q = this.organizationQuery

      this.$router.push({ name: 'organization-list', query })
    },
    deleteOrganization (organization) {
      if (!confirm('Are you sure ?')) return
      this.errorMessage = false
      this.deleted = false
      organization.destroy().then(() => {
        this.getOrganizations(this.currentPage, this.organizationQuery)
      }).catch((error) => {
        this.errorMessage = error.response.data.message
      })
    }
  },
  watch: {
    '$route.query': {
      handler ({ page, q }) {
        this.getOrganizations(page, q)
      },
      deep: true,
      immediate: true
    }
  }
}
</script>

<style scoped lang="scss">
.organizations.grid {
  margin-bottom: 1em!important;
}
</style>
