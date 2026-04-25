pub const profile_query =
    \\query($login: String!, $from: DateTime!, $to: DateTime!) {
    \\  user(login: $login) {
    \\    name
    \\    login
    \\    bio
    \\    avatarUrl
    \\    createdAt
    \\    followers { totalCount }
    \\    following { totalCount }
    \\    pullRequests { totalCount }
    \\    issues { totalCount }
    \\    repositories(first: 100, ownerAffiliations: [OWNER], isFork: false, orderBy: {field: STARGAZERS, direction: DESC}) {
    \\      totalCount
    \\      nodes {
    \\        name
    \\        description
    \\        url
    \\        stargazerCount
    \\        forkCount
    \\        primaryLanguage { name color }
    \\        languages(first: 10, orderBy: {field: SIZE, direction: DESC}) {
    \\          edges { size node { name color } }
    \\        }
    \\      }
    \\    }
    \\    contributionsCollection(from: $from, to: $to) {
    \\      totalCommitContributions
    \\      totalPullRequestContributions
    \\      totalIssueContributions
    \\      totalRepositoriesWithContributedCommits
    \\      contributionCalendar {
    \\        totalContributions
    \\        weeks {
    \\          contributionDays { date contributionCount weekday }
    \\        }
    \\      }
    \\      commitContributionsByRepository(maxRepositories: 100) {
    \\        repository { nameWithOwner primaryLanguage { name color } }
    \\        contributions(first: 100) { nodes { commitCount } }
    \\      }
    \\    }
    \\  }
    \\  rateLimit { remaining resetAt }
    \\}
;
