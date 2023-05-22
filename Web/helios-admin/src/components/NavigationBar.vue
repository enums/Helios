<script  lang="ts" setup>
import {
  MessageBox,
  DataLine,
  Document,
  Monitor,
  Wallet,
  Cpu,
} from '@element-plus/icons-vue'
</script>

<template>
  <el-menu :router="true" :default-active="activeLink">

    <el-menu-item index="/">
      <el-icon>
        <DataLine />
      </el-icon>
      <span>
        Overall
      </span>
    </el-menu-item>

    <el-menu-item index="/service">
      <el-icon>
        <Monitor />
      </el-icon>
      <span>
        Service
      </span>
    </el-menu-item>
    <el-sub-menu index="3">
      <template #title>
        <el-icon>
          <Document />
        </el-icon>
        <span>Logs</span>
      </template>
      <el-menu-item index="3-1">Overall</el-menu-item>
      <el-menu-item index="3-2">History</el-menu-item>
    </el-sub-menu>

    <el-sub-menu index="1">
      <template #title>
        <el-icon>
          <MessageBox />
        </el-icon>
        <span>Mailbox</span>
      </template>
      <el-menu-item index="1-1">Overall</el-menu-item>
      <el-menu-item index="1-2">History</el-menu-item>
    </el-sub-menu>

    <el-sub-menu index="2">
      <template #title>
        <el-icon>
          <Wallet />
        </el-icon>
        <span>Payment</span>
      </template>
      <el-menu-item index="2-1">Overall</el-menu-item>
      <el-menu-item index="2-2">History</el-menu-item>
    </el-sub-menu>

    <el-menu-item index="/about">
      <el-icon>
        <Cpu />
      </el-icon>
      <span>
        About
      </span>
    </el-menu-item>
  </el-menu>

</template>
  
<script lang="ts">

export default {
  data() {
    return {
      activeLink: null,
    }
  },
  watch: {
    $route(to, from) {
      this.activeLink = to.path;
    }
  },
  mounted: function () {
    this.activeLink = this.$route.path;
  },
  methods: {
  }
};


</script>

<style>

</style>