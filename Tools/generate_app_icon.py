#!/usr/bin/env python3
"""Compatibility entry point for the canonical Nexora icon generator.

All five in-app previews and all five iOS app-icon sets now come from the
approved artwork through one pipeline. This wrapper prevents the former,
unrelated vector redraw from replacing the primary icon.
"""

from generate_alternate_icons import main


if __name__ == "__main__":
    main()
