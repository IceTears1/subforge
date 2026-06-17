#!/bin/bash
# SubForge Release Script
# Create a new release with tag

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}SubForge Release${NC}"
echo "================"
echo ""

# Check if in git repo
if [ ! -d ".git" ]; then
    echo -e "${RED}Not a git repository${NC}"
    exit 1
fi

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    echo -e "${YELLOW}Warning: You have uncommitted changes:${NC}"
    git status --short
    echo ""
    read -p "$(echo -e ${YELLOW}Continue anyway? [y/N]: ${NC})" CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        echo "Cancelled"
        exit 0
    fi
fi

# Get current version
CURRENT_TAG=$(git describe --tags --exact-match HEAD 2>/dev/null || echo "")
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")

echo -e "Current tag: ${CYAN}${CURRENT_TAG:-none}${NC}"
echo -e "Latest tag:  ${CYAN}${LATEST_TAG}${NC}"
echo ""

# Calculate next version
IFS='.' read -r MAJOR MINOR PATCH <<< "${LATEST_TAG#v}"
PATCH=$((PATCH + 1))
NEXT_VERSION="v${MAJOR}.${MINOR}.${PATCH}"

echo -e "${YELLOW}Version bump options:${NC}"
echo "  1) Patch: ${CYAN}${NEXT_VERSION}${NC} (bug fixes)"
echo "  2) Minor: ${CYAN}v${MAJOR}.$((MINOR+1)).0${NC} (new features)"
echo "  3) Major: ${CYAN}v$((MAJOR+1)).0.0${NC} (breaking changes)"
echo "  4) Custom version"
echo ""
read -p "$(echo -e ${CYAN}Select option [1-4]: ${NC})" OPTION

case $OPTION in
    1)
        VERSION=$NEXT_VERSION
        ;;
    2)
        VERSION="v${MAJOR}.$((MINOR+1)).0"
        ;;
    3)
        VERSION="v$((MAJOR+1)).0.0"
        ;;
    4)
        read -p "$(echo -e ${CYAN}Enter version (e.g., v1.2.3): ${NC})" VERSION
        ;;
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "Creating release: ${GREEN}${VERSION}${NC}"
echo ""

# Get commit messages since last tag
echo -e "${YELLOW}Changes since ${LATEST_TAG}:${NC}"
if [ -n "$LATEST_TAG" ]; then
    git log --oneline "${LATEST_TAG}..HEAD"
else
    git log --oneline -10
fi
echo ""

# Confirm
read -p "$(echo -e ${YELLOW}Create release ${VERSION}? [y/N]: ${NC})" CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Cancelled"
    exit 0
fi

# Create tag
echo -e "${YELLOW}[1/3] Creating tag...${NC}"
git tag -a "$VERSION" -m "Release $VERSION"
echo -e "  ${GREEN}Tag ${VERSION} created${NC}"

# Push tag
echo -e "${YELLOW}[2/3] Pushing tag...${NC}"
git push origin "$VERSION"
echo -e "  ${GREEN}Tag pushed${NC}"

# Push main branch
echo -e "${YELLOW}[3/3] Pushing main branch...${NC}"
git push origin main
echo -e "  ${GREEN}Main branch pushed${NC}"

echo ""
echo -e "${GREEN}================${NC}"
echo -e "${GREEN}Release ${VERSION} created!${NC}"
echo ""
echo -e "  Users can now update to ${CYAN}${VERSION}${NC}"
echo -e "  via the web UI or API"
echo ""
echo -e "  ${YELLOW}GitHub Release:${NC}"
echo -e "    https://github.com/IceTears1/subforge/releases/tag/${VERSION}"
echo ""
