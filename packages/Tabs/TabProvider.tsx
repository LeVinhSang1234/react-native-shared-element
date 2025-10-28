import { createContext, PropsWithChildren, useContext } from 'react';

const TabItemContext = createContext(false);

export const useTabFocus = () => useContext(TabItemContext);

export function TabItemProvider(props: PropsWithChildren<{ focus: boolean }>) {
  return (
    <TabItemContext.Provider value={props.focus}>
      {props.children}
    </TabItemContext.Provider>
  );
}

// ---------- TAB NAVIGATION ------------- //

interface TNavigationContext {
  navigate: (name: string) => void;
}

const TabNavigationContext = createContext<TNavigationContext>({
  navigate: () => null,
});

export const useTabNavigation = () => useContext(TabNavigationContext);

function TabProvider(props: PropsWithChildren<TNavigationContext>) {
  const { children, ...p } = props;
  return (
    <TabNavigationContext.Provider value={p}>
      {children}
    </TabNavigationContext.Provider>
  );
}

export default TabProvider;
